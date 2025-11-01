; Boot Sector for FEPOS (FAT12 format)
; Assembled with NASM: origin set to 0x7C00, 16-bit mode.

ORG 0x7C00           ; Indica que o BIOS carrega o setor de boot em 0x7C00
BITS 16              ; Utiliza o conjunto de instruções de 16 bits

    ; Pulamos os dados do BPB/EBR (informações armazenadas no disco) para
    ; iniciar a execução do código principal.
    JMP SHORT main  ; Pula para o rótulo 'main'
    NOP             ; Instrução NOP (No Operation) para alinhamento ou preenchimento

; -------------------------
; BIOS Parameter Block (BPB)
; Bloco que contém os parâmetros do disco e do sistema de arquivos, conforme
; definido pela especificação FAT. Está armazenado no setor de boot.
; -------------------------

bpb_oem:                DB 'MSWIN4.1'       ; Identificador OEM (8 bytes): indica que a 
                                            ; formatação foi feita com MSWIN4.1
bpb_bytes_per_sector:   DW 512              ; Número de bytes por setor; valor padrão 512
bpb_sectors_per_cluster: DB 1               ; Quantidade de setores por cluster; 1 setor/cluster
bpb_reserved_sectors:   DW 1                ; Número de setores reservados (setor de boot é reservado)
bpb_fat_count:          DB 2                ; Número de cópias da FAT (geralmente 2 para redundância)
bpb_dir_entries_count:  DW 0xe0             ; Máximo de entradas no diretório raiz (224 entradas para FAT12)
bpb_total_sectors:      DW 2880             ; Total de setores do disco (2880 setores = 1,44MB, típico de disquete)
bpb_media_descriptor_type: DB 0xf0          ; Descritor de mídia (0xF0 indica disquete)
bpb_sectors_per_fat:    DW 9                ; Número de setores que cada cópia da FAT ocupa (9 setores)
bpb_sectors_per_track:  DW 18               ; Número de setores por trilha (18 setores, típico para disquetes 3.5")
bpb_heads:              DW 2                ; Número de cabeças (2, para disquetes de dupla face)
bpb_hidden_sectors:     DD 0                ; Setores ocultos antes da partição (0 para disquete)
bpb_large_sector_count: DD 0                ; Contagem de setores para discos grandes (não usado em disquetes)

; -------------------------
; Extended Boot Record (EBR) Fields
; Campos estendidos logo após o BPB que fornecem informações extras do volume.
; -------------------------

ebr_drive_number:       DB 0                ; Número da unidade (0 indica geralmente a unidade A:)
ebr_reserved:           DB 0                ; Reservado (a menos que fossem flags do Win NT)
ebr_signature:          DB 0x29             ; Assinatura de boot (0x29 indica que os campos seguintes são válidos)
ebr_volume_id:          DD 0x13371337       ; Número de série do volume (4 bytes em ordem little-endian)
ebr_volume_label:       DB 'FELIPE   OS'      ; Rótulo do volume (11 caracteres, preenchidos com espaços)
ebr_system_id:          DB 'FAT12      '    ; Identificação do sistema de arquivos (ex.: "FAT12", com 11 caracteres)

; -------------------------
; Main Boot Code (Código de Boot Principal)
; -------------------------
main:
    MOV AX, 0         ; Zera o registrador AX
    MOV DS, AX        ; Define DS = 0 (o setor de boot está mapeado a partir do endereço 0)
    MOV ES, AX        ; Define ES = 0
    MOV SS, AX        ; Define SS = 0

    MOV SP, 0x7C00    ; Inicializa o ponteiro de pilha (SP) para o topo do setor de boot (descendente)
    ; 1. LIMPA A TELA (Scroll Up)
    PUSH AX
    PUSH CX
    PUSH DX
    
    MOV AH, 0x06 ; AH = 06h: Função Scroll Up
    MOV AL, 0x00 ; AL = 0: Limpa a área
    MOV BH, 0x07 ; Atributo (Branco sobre Preto)
    MOV CX, 0x0000 ; Início da área (0,0)
    MOV DX, 0x184F ; Fim da área (24,79)
    INT 0x10
    
    ; 2. REPOSICIONA O CURSOR (INT 10h, AH=02h)
    MOV AH, 0x02 ; AH = 02h: Set Cursor Position
    MOV BH, 0x00 ; Página de vídeo (0)
    MOV DH, 0x00 ; Linha (Row) 0
    MOV DL, 0x00 ; Coluna (Column) 0
    INT 0x10
    
    POP DX
    POP CX
    POP AX
   

    ;----------------------------------------------------------------
    ; Cálculo para localizar o diretório raiz:
    ; - A área reservada ocupa 1 setor.
    ; - Cada FAT ocupa 9 setores e há 2 cópias, totalizando 18 setores.
    ; - Logo, a partir do LBA da raiz: (FatSectors * FatCount) + ReservedSectors. = 19
    ;----------------------------------------------------------------

        MOV AX, [bpb_sectors_per_fat]   ; AX recebe o número de setores por FAT
        MOV BL, [bpb_fat_count]           ; BL recebe a quantidade de cópias da FAT
        XOR BH, BH                      ; Zera BH para formar BX corretamente
        MUL BX                          ; AX = setores por FAT * quantidade de FATs
        ADD AX, [bpb_reserved_sectors]  ; Adiciona o número de setores reservados -> LBA do diretório raiz
        PUSH AX                       ; Salva LBA inicial do diretório raiz na pilha

        MOV AX, [bpb_dir_entries_count] ; Carrega o número de entradas no diretório raiz
        SHL AX, 5                       ; Multiplica por 32 (cada entrada tem 32 bytes)
        XOR DX, DX                      ; Zera DX para a divisão
        DIV WORD [bpb_bytes_per_sector] ; Divide pelo número de bytes por setor para saber quantos setores o diretório ocupa

        TEST DX, DX                     ; Testa se houve resto na divisão
        JZ rootDirAfter                 ; Se não houver resto, o número de setores está exato
        INC AX                          ; Se houver resto, incrementa (uma setor extra é necessário)

rootDirAfter:
        MOV CL, AL                      ; Armazena CL o número de setores ocupados pelo diretório raiz
        POP AX                          ; Recupera o LBA inicial do diretório raiz da pilha
        MOV DL, [ebr_drive_number]      ; Carrega o número da unidade (drive)
        MOV BX, buffer                  ; Carrega o endereço do buffer para leitura de dados
        CALL disk_reader                ; Lê os setores do diretório raiz para o buffer

        XOR BX, BX                      ; Zera BX (irá ser usado como índice para percorrer as entradas do diretório)
        MOV DI, buffer                  ; DI aponta para o início do buffer (lista de entradas do diretório)

;----------------------------------------------------------------
; Procura a entrada de diretório do Kernel (arquivo chamado "KERNEL  BIN")
;----------------------------------------------------------------
searchKernel:
        MOV SI, file_kernel_bin         ; SI recebe o endereço da cadeia de caracteres "KERNEL  BIN"
        MOV CX, 11                      ; CX recebe 11 (tamanho fixo da string de nome no FAT)
        PUSH DI                         ; Salva DI (ponteiro atual da entrada de diretório)
        REPE CMPSB                    ; Compara 11 bytes do diretório com "KERNEL  BIN"
        POP DI                          ; Restaura DI
        JE foundKernel                  ; Se forem iguais, encontrou a entrada do kernel

        ADD DI, 32                      ; Avança para a próxima entrada (cada entrada tem 32 bytes)
        INC BX                          ; Incrementa o índice de entrada
        CMP BX, [bpb_dir_entries_count] ; Verifica se ainda está dentro do limite de entradas
        JL searchKernel                 ; Se sim, continua a busca

        JMP kernelNotFound              ; Se nenhuma entrada corresponder, vai para o rótulo de erro

kernelNotFound:
        MOV SI, msg_kernel_not_found    ; Carrega mensagem de erro "KERNEL.BIN not found!"
        CALL print                      ; Imprime a mensagem de erro
        HLT                             ; Para a execução do sistema
        JMP halt                        ; (Fallback, loop infinito)

;----------------------------------------------------------------
; Se a entrada for encontrada, extrai o número do cluster inicial do kernel.
;----------------------------------------------------------------
foundKernel:
        MOV AX, [DI+26]                 ; O offset 26 na entrada do diretório contém o cluster inicial
        MOV [kernel_cluster], AX        ; Armazena o número do cluster inicial do Kernel

;----------------------------------------------------------------
; Leitura da FAT para seguir a cadeia de clusters do kernel
;----------------------------------------------------------------
        MOV AX, [bpb_reserved_sectors]  ; AX recebe a quantidade de setores reservados
        MOV BX, buffer                  ; BX aponta para o buffer (usado para ler o FAT)
        MOV CL, [bpb_sectors_per_fat]   ; CL recebe o número de setores por FAT
        MOV DL, [ebr_drive_number]      ; DL recebe o número da unidade
        CALL disk_reader                ; Lê a FAT do disco e carrega para o buffer

        MOV BX, kernel_load_segment     ; BX recebe o segmento destino para carregar o kernel
        MOV ES, BX                      ; ES = segmento para onde o kernel será carregado
        MOV BX, kernel_load_offset      ; BX recebe o offset de carregamento dentro do segmento

;----------------------------------------------------------------
; Loop para leitura de clusters do kernel conforme a cadeia na FAT
;----------------------------------------------------------------
loadKernelLoop:
        MOV AX, [kernel_cluster]        ; Carrega o número do cluster atual do kernel
        ADD AX, 31                      ; Ajusta o valor para calcular o offset no FAT (cálculo FAT12)
        MOV CL, 1                       ; CL: quantidade de setores a ler (1 por vez)
        MOV DL, [ebr_drive_number]      ; DL: número da unidade
        CALL disk_reader                ; Lê o setor correspondente do FAT

        ADD BX, [bpb_bytes_per_sector]  ; Incrementa o offset de carga do kernel pelo tamanho de um setor

        MOV AX, [kernel_cluster]        ; Retorna o número atual do cluster
        MOV CX, 3                       ; Multiplica por 3 (para obter a posição do registro FAT, pois FAT12 usa 12-bit)
        MUL CX                          ; AX = kernel_cluster * 3
        MOV CX, 2                       ; Divisor (para separar a entrada de 12 bits)
        DIV CX                          ; Divide para extrair o registro da FAT

        MOV SI, buffer                  ; SI aponta para o início do buffer (FAT lido)
        ADD SI, AX                      ; Avança para a posição exata do registro FAT para o cluster atual
        MOV AX, [DS:SI]                 ; Carrega o registro FAT (16 bits) em AX

        OR DX, DX                       ; Testa se houve resto na divisão (determina par/ímpar no empacotamento do FAT12)
        JZ even                       ; Se DX for zero, trata como entrada par
odd:
        SHR AX, 4                       ; Se for ímpar, desloca 4 bits para a direita para obter os 12 bits válidos
        JMP nextClusterAfter            ; Vai para atualização do cluster seguinte
even:
        AND AX, 0x0FFF                  ; Se for par, mascara os 12 bits relevantes da entrada

nextClusterAfter:
        CMP AX, 0x0FF8                 ; Compara se o valor indica o fim da cadeia (marcador de fim do arquivo para FAT12)
        JAE readFinish                  ; Se chegar ao fim, sai do loop
       
        MOV [kernel_cluster], AX        ; Atualiza o valor de kernel_cluster com o próximo cluster
        JMP loadKernelLoop              ; Repete a leitura para o próximo cluster

readFinish:
        MOV DL, [ebr_drive_number]      ; Carrega novamente o número da unidade em DL
        MOV AX, kernel_load_segment     ; AX recebe o segmento de carga do kernel
        MOV DS, AX                      ; Define DS = segmento de carga (para acesso adequado em memória)
        MOV ES, AX                      ; Define ES = segmento de carga
       
        JMP kernel_load_segment:kernel_load_offset
        ; Salta para o kernel carregado: endereço definido por kernel_load_segment:kernel_load_offset

        HLT                           ; Em caso de falha na transferência, termina a execução

halt:
        JMP halt                      ; Loop infinito: garante que, se HLT não funcionar, o sistema não continue

;----------------------------------------------------------------
; Subroutine: lba_to_chs
; Converte um endereço LBA para os endereços Cylinder-Head-Sector (CHS)
; Entrada:
;    AX = número LBA
; Saída:
;    CX: Bits 0-5: número do setor (1-based) e bits 6-15: parte do cilindro
;    DH = Cabeça (head)
;----------------------------------------------------------------
lba_to_chs:
    PUSH ax
    PUSH dx

    XOR dx,dx
    DIV word [bpb_sectors_per_track] ; Divide AX pelo número de setores por trilha (setor = resto da divisão)
    INC DX                        ; Incrementa DX para que os setores sejam contados a partir de 1
    MOV CX, DX                    ; Armazena o número do setor em CX (parte baixa)

    XOR DX,dx
    DIV word [bpb_heads]          ; Divide AX pelo número de cabeças; o quociente representa cilindro e o resto a cabeça
    MOV DH, DL                    ; Define DH com o valor da cabeça
    MOV CH, AL                    ; AL contém agora o número do cilindro
    SHL AH, 6                     ; Prepara os bits superiores do cilindro deslocando AH 6 posições à esquerda
    OR CL, AH                     ; Combina os bits para formar o número completo do cilindro em CX

    POP ax
    MOV DL,AL
    POP ax

    RET

;----------------------------------------------------------------
; Subroutine: disk_reader
; Lê setores do disco convertendo LBA para CHS e utilizando a interrupção INT 13h.
; Entradas:
;    AX = índice LBA (usado pela lba_to_chs)
;    CX = número de setores (com informações de cilindro, conforme formatação FAT)
;    DL = número da unidade (drive)
;    BX = ponteiro para o buffer onde os dados serão armazenados
; Saída:
;    O buffer é preenchido com os dados lidos do setor (ou setores) do disco.
;----------------------------------------------------------------
disk_reader:
    PUSH ax
    PUSH bx
    PUSH cx
    PUSH dx
    PUSH di

    CALL lba_to_chs   ; Converte LBA para CHS (obtém os valores em CH, CL, DH)

    MOV AH, 02h       ; Função 02h da INT 13h: leitura de setor(s)
    MOV DI, 3         ; Define contador de tentativas (3 tentativas)

retry:
    STC               ; Seta a flag de transporte (prepara para chamada de INT 13h)
    INT 13h           ; Chama o BIOS para ler os setores especificados
    JNC doneRead      ; Se não ocorrer erro (flag de transporte limpa), salta para doneRead

    CALL diskReset    ; Em caso de erro, chama a rotina para resetar o disco

    DEC DI            ; Decrementa o contador de tentativas
    TEST DI,DI       ; Se DI não for zero, continua tentando
    JNZ retry

failDiskRead:
    MOV SI, read_failure   ; Carrega mensagem de erro "Failed to read disk!"
    CALL print             ; Imprime a mensagem
    HLT                   ; Interrompe a execução
    JMP halt              ; Em caso extremo, entra num loop infinito

diskReset:
    PUSHA                ; Salva todos os registradores
    MOV AH,0           ; Função 0 da INT 13h: reset do disco
    STC                 ; Seta a flag de transporte
    INT 13h             ; Chama a função de reset
    JC failDiskRead     ; Se ocorrer erro, salta para a rotina de falha
    POPA                ; Restaura os registradores
    RET

doneRead:
    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET

;----------------------------------------------------------------
; Subroutine: print
; Exibe uma string terminada em zero apontada por SI usando a INT 10h (saída teletipo)
;----------------------------------------------------------------
print:
    PUSH SI          ; Salva o ponteiro para a string (SI)
    PUSH AX          ; Salva AX
    PUSH BX          ; Salva BX

print_loop:
    LODSB            ; Carrega o byte em DS:SI para AL e incrementa SI
    OR AL, AL        ; Testa se AL é zero (final da string)
    JZ done_print    ; Se zero, finaliza a impressão

    MOV AH, 0x0E     ; Configura AH para 0x0E (função teletipo da BIOS)
    MOV BH, 0        ; Define BH como 0 (página padrão)
    INT 0x10         ; Chama a interrupção de vídeo para exibir o caractere em AL

    JMP print_loop   ; Repete até terminar a string

done_print:
    POP BX           ; Restaura BX
    POP AX           ; Restaura AX
    POP SI           ; Restaura SI
    RET              ; Retorna da sub-rotina

;----------------------------------------------------------------
; Dados e Mensagens
;----------------------------------------------------------------
read_failure DB 'Falha ao ler disco!', 0x0D, 0X0A, 0
; Mensagem de erro caso a leitura do disco falhe

file_kernel_bin DB 'KERNEL  BIN'
; Nome do arquivo kernel conforme esperado no diretório (11 caracteres no formato FAT)

msg_kernel_not_found DB 'KERNEL.BIN not found!'
; Mensagem de erro se o arquivo kernel não for localizado no diretório raiz

kernel_cluster DW 0
; Variável para armazenar o número do cluster inicial do kernel

kernel_load_segment EQU 0x2000
; Segmento de memória onde o kernel deverá ser carregado

kernel_load_offset EQU 0
; Offset dentro do segmento onde o kernel será carregado (início do segmento)

;----------------------------------------------------------------
; Preenchimento e Assinatura do Setor de Boot
;----------------------------------------------------------------
TIMES 510 - ($ - $$) DB 0  ; Preenche com zeros até que o boot sector tenha 510 bytes
DW 0AA55h                ; Assinatura do setor de boot (0xAA55), obrigatória para a BIOS reconhecer o boot sector

buffer:
; Área de buffer utilizada para ler dados do disco (FAT, diretório, etc.)
