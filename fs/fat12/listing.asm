
; --------------------------------------------------------------------------
; file_exists -- Verifica a presença de um arquivo no disquete
; IN:  AX = ponteiro para o nome do arquivo
; OUT: Carry clear (CF=0) se encontrado
;      Carry set   (CF=1) se não encontrado/erro
; --------------------------------------------------------------------------

file_exists:
    ; --- Normaliza o nome ---
    call string_uppercase        ; Converte string em AX (nome) para maiúsculas
    call int_filename_convert    ; Converte para formato FAT12 8.3
                                 ; Se inválido, CF=1 → erro imediato

    ; --- Verifica se string não é vazia ---
    push ax                      ; Salva ponteiro do nome convertido
    call string_length           ; AX ← comprimento da string
    cmp ax, 0                    ; É zero?
    je .failure                  ; Se comprimento=0 → falha
    pop ax                       ; Restaura ponteiro do nome (se não falhou)

    ; --- Lê diretório raiz ---
    push ax                      ; Salva ponteiro do nome
    call disk_read_root_dir      ; Carrega root dir para disk_buffer
    ; (Carry=1 se falha de leitura)

    pop ax                       ; Restaura ponteiro do nome

    ; --- Procura entrada no diretório ---
    mov di, disk_buffer          ; DI = início do buffer do root dir
    call disk_get_root_entry     ; Procura entrada com nome em AX
                                 ; Se encontrado → CF=0
                                 ; Se não encontrado → CF=1

    ret                          ; Retorna com Carry indicando resultado

.failure:
    pop ax                       ; Desempilha ponteiro salvo (limpeza da pilha)
    stc                          ; Força Carry=1 → falha
    ret                          ; Retorna

; ------------------------------------------------------------------
; get_file_list
; ------------------------------------------------------------------
; Objetivo:
;   Ler o diretório raiz do disquete (FAT12) e gerar uma string
;   contendo os nomes de arquivos, separados por vírgula, terminada
;   em zero (null-terminated).
;
; Contrato:
;   Entrada:
;     AX = endereço de memória onde a lista de nomes será armazenada
;   Saída:
;     No buffer apontado por AX, será gravada a lista de nomes
;     (ex.: "FILE1.TXT,FILE2.BIN,...\0")
;   Preservação:
;     Todos os registradores são preservados (pusha/popa).
;
; Contexto FAT12:
;   - O diretório raiz de um disquete FAT12 começa no setor lógico 19.
;   - Cada entrada de diretório tem 32 bytes.
;   - Entradas podem ser arquivos, diretórios, volume label ou marcadores
;     especiais (apagado, nunca usado, LFN).
;   - Precisamos filtrar apenas arquivos válidos.
; ------------------------------------------------------------------
get_file_list:
    pusha                           ; Salva todos os registradores

    mov word [get_file_list_tmp_var], ax
                                    ; Salva o endereço de destino (buffer de saída)
                                    ; em uma variável global temporária.
                                    ; Esse será o local onde os nomes serão gravados.

    mov eax, 0                      ; Zera EAX (compatibilidade com BIOS antigas
                                    ; que podem ler registradores de 32 bits)

    call floppy_reset          ; Reseta o controlador de disquete
                                    ; (precaução: caso o disco tenha sido trocado)

    mov ax, 19                      ; O diretório raiz começa no setor lógico 19
    call lba_to_chs         ; Converte LBA (Logical Block Address) para
                                    ; CHS (Cylinder-Head-Sector), formato exigido
                                    ; pela BIOS INT 13h

    mov si, disk_buffer             ; SI aponta para o buffer de disco
    mov bx, si                      ; BX também aponta para o buffer (ES:BX usado por INT 13h)

    mov ah, 2                       ; Função 02h da INT 13h: "Read Sectors"
    mov al, 14                      ; Ler 14 setores (tamanho típico do diretório raiz em FAT12)

    pusha                           ; Prepara para entrar no loop de leitura


; ------------------------------------------------------------------
; Loop de leitura do diretório raiz
; ------------------------------------------------------------------
get_file_list_read_root_dir:
    popa
    pusha

    stc                             ; Define Carry Flag antes da chamada
                                    ; (algumas BIOS só limpam CF em caso de sucesso)
    int 13h                         ; Chama BIOS para ler setores do disquete
    jnc get_file_list_show_dir_init ; Se não houve erro (CF=0), continua

    ; Caso ocorra erro de leitura:
    call floppy_reset          ; Tenta resetar o controlador
    jnc get_file_list_read_root_dir ; Se reset bem-sucedido, tenta novamente
    jmp get_file_list_done_error    ; Se falhar de novo, aborta a rotina


; ------------------------------------------------------------------
; Inicialização da varredura do diretório
; ------------------------------------------------------------------
get_file_list_show_dir_init:
    popa

    mov ax, 0                       ; Zera AX (pode ser usado como contador auxiliar)
    mov si, disk_buffer             ; SI aponta para o início do buffer de diretório
                                    ; (cada entrada tem 32 bytes)

    mov word di, [get_file_list_tmp_var]
                                    ; DI = endereço do buffer de saída
                                    ; (onde os nomes de arquivos serão gravados)


; ------------------------------------------------------------------
; Início da análise de cada entrada de diretório
; ------------------------------------------------------------------
get_file_list_start_entry:
    mov al, [si+11]                 ; Lê o byte de atributos da entrada (offset 11)
    cmp al, 0x0F                    ; 0x0F = entrada de LFN (Long File Name, Windows)
    je get_file_list_skip            ; Se for LFN, ignorar

    test al, 0x18                   ; Testa bits 3 e 4 (0x08 = volume label, 0x10 = diretório)
    jnz get_file_list_skip           ; Se for diretório ou volume label, ignorar

    mov al, [si]                    ; Lê o primeiro byte do nome
    cmp al, 229                     ; 0xE5 = entrada marcada como deletada
    je get_file_list_skip            ; Ignora entradas deletadas

    cmp al, 0                       ; 0 = entrada nunca usada (fim da lista)
    je get_file_list_done            ; Se encontrado, fim do diretório


    ; Se chegou aqui, a entrada é válida (arquivo normal)
    mov cx, 1                       ; CX = contador de caracteres (inicializa em 1)
    mov dx, si                      ; DX = ponteiro para o início da entrada
                                    ; (será usado para copiar nome para o buffer de saída)

; --------------------------------------------------------------
; get_file_list_testdirentry
; --------------------------------------------------------------
; Objetivo:
;   Validar o nome do arquivo presente na entrada de diretório FAT12.
;   Verifica se os caracteres do nome (até 11 bytes: 8 para nome + 3 para extensão)
;   estão dentro do intervalo ASCII imprimível permitido (' ' a '~').
;
; Contexto:
;   - Em FAT12, o nome é armazenado fixo em 11 bytes:
;       [0..7] = nome (padded com espaços)
;       [8..10] = extensão (padded com espaços)
;   - Caracteres inválidos/não imprimíveis indicam que a entrada é inutilizável
;     para exibição como arquivo.
;   - SI aponta para o início da entrada (DX foi salvo como início de entrada).
;   - CX está sendo usado como contador de caracteres validados.
; --------------------------------------------------------------
get_file_list_testdirentry:
    inc si                       ; Avança para o próximo caractere do nome dentro da entrada
    mov al, [si]                 ; Carrega o caractere atual do nome/extensão

    ; Teste de faixa ASCII: rejeita abaixo de ' ' (0x20) e acima de '~' (0x7E)
    cmp al, ' '                  ; Se al < ' ', é inválido
    jl get_file_list_nxtdirentry ; Vai para a próxima entrada
    cmp al, '~'                  ; Se al > '~', é inválido
    ja get_file_list_nxtdirentry ; Vai para a próxima entrada

    inc cx                       ; Incrementa contador de caracteres válidos
    cmp cx, 11                   ; Já validou os 11 bytes (8 nome + 3 extensão)?
    je get_file_list_gotfilename ; Sim: temos um nome válido para copiar
    jmp get_file_list_testdirentry ; Não: continue testando o próximo byte


; --------------------------------------------------------------
; get_file_list_gotfilename
; --------------------------------------------------------------
; Objetivo:
;   Copiar o nome e extensão (formato 8.3) do diretório para o buffer de saída,
;   removendo espaços de padding e inserindo um ponto entre nome e extensão.
;
; Contrato:
;   - SI será reposicionado para o início da entrada (DX contém o início).
;   - DI aponta para o buffer de saída (lista de arquivos).
;   - Copia até 11 caracteres da entrada:
;       * Para os primeiros 8, ignora espaços e, ao completar 8, insere um '.'
;       * Para os últimos 3, ignora espaços (não copia nada se extensão estiver em branco)
;   - Ao final, adiciona uma vírgula para separar nomes.
; --------------------------------------------------------------
get_file_list_gotfilename:        ; Chegou aqui com um nome que passou nos testes
    mov si, dx                    ; SI = início da entrada atual (DX guardado previamente)
    mov cx, 0                     ; Reinicia o contador de caracteres copiados (0..11)

get_file_list_loopy:
    mov al, [si]                  ; Lê próximo byte da entrada (nome/extensão)
    cmp al, ' '                   ; Espaço é padding em FAT (não deve ser copiado)
    je get_file_list_ignore_space ; Se espaço, pula sem copiar

    mov byte [di], al             ; Copia o caractere válido para o buffer de saída
    inc si                        ; Avança leitura na entrada
    inc di                        ; Avança escrita no buffer
    inc cx                        ; Incrementa quantidade de tratados (nome + extensão)
    cmp cx, 8                     ; Já tratou os 8 chars do nome?
    je get_file_list_add_dot      ; Se sim, insere o ponto separador
    cmp cx, 11                    ; Já tratou os 11 (8+3)?
    je get_file_list_done_copy    ; Finaliza cópia desse nome
    jmp get_file_list_loopy       ; Continua a varredura

get_file_list_ignore_space:
    inc si                        ; Apenas avança na entrada (não escreve)
    inc cx                        ; Conta para posição lógica dentro do 8.3
    cmp cx, 8                     ; Ao terminar os 8 do nome,
    je get_file_list_add_dot      ; insere o ponto
    jmp get_file_list_loopy       ; Continua a análise

get_file_list_add_dot:
    mov byte [di], '.'            ; Insere o separador entre nome e extensão
    inc di
    jmp get_file_list_loopy       ; Volta para continuar copiando a extensão

get_file_list_done_copy:
    mov byte [di], ','            ; Adiciona vírgula para separar arquivos na lista
    inc di                        ; Avança posição de escrita


; --------------------------------------------------------------
; Avanço para próxima entrada (ou pular entrada inválida)
; --------------------------------------------------------------
; Objetivo:
;   Preparar SI para apontar para a próxima entrada de diretório
;   (cada entrada tem 32 bytes). Reutiliza DX como “reinício” lógico.
; --------------------------------------------------------------
get_file_list_nxtdirentry:
    mov si, dx                    ; Restaura SI para o início da entrada
                                  ; (permitindo lógica consistente ao pular)
get_file_list_skip:
    add si, 32                    ; Avança 32 bytes: próxima entrada de diretório
    jmp get_file_list_start_entry ; Retorna ao laço principal de análise


; --------------------------------------------------------------
; Finalização bem-sucedida da lista
; --------------------------------------------------------------
; Objetivo:
;   Remover a vírgula final e terminar a string com zero.
;   Sinalizar sucesso (CF=0).
; --------------------------------------------------------------
get_file_list_done:               ; Encontrado 0x00 (entrada nunca usada) ou fim lógico
    dec di                        ; Volta uma posição para substituir a última vírgula
    mov byte [di], 0              ; Coloca terminador nulo no fim da lista

    popa                          ; Restaura registradores salvos
    clc                           ; CF = 0 (sucesso)
    ret


; --------------------------------------------------------------
; Finalização com erro
; --------------------------------------------------------------
; Objetivo:
;   Sinalizar erro de leitura (CF=1) e restaurar contexto.
; --------------------------------------------------------------
get_file_list_done_error:
    popa                          ; Restaura registradores
    stc                           ; CF = 1 (falha)
    ret


; --------------------------------------------------------------
; Variáveis globais
; --------------------------------------------------------------
; Armazena o ponteiro de destino (buffer de saída) passado em AX
; no início de get_file_list. Necessário porque a rotina troca de
; contexto várias vezes e precisa recuperar DI corretamente.
get_file_list_tmp_var    dw 0