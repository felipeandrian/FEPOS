; ==================================================================
; src/kernel/main.asm - Ponto de Entrada do FEP OS
; ==================================================================

bits 16                 ; Define que o código será montado em modo 16 bits
org 0x0000              ; Origem lógica do código (endereço base do kernel na memória)

    ; --------------------------------------------------------------
    ; Definição de área de buffer para operações de disco
    ; --------------------------------------------------------------
    ; O buffer começa em 24 KB após o ponto de carregamento do kernel.
    ; Ele possui 8 KB de tamanho, pois a partir de 32 KB começam a ser
    ; carregados programas externos. Assim, evita-se sobreposição.
    ; --------------------------------------------------------------
    disk_buffer equ 24576   ; Endereço base do buffer de disco (24K)

; --------------------------------------------------------------
; Ponto de Entrada do Kernel
; --------------------------------------------------------------
kernel_start:
    ; Configuração inicial dos segmentos de memória
    mov ax, 0x2000       ; Define o segmento base do kernel (0x2000)
    mov ds, ax           ; DS = 0x2000 (segmento de dados)
    mov es, ax           ; ES = 0x2000 (segmento extra)
    mov ss, ax           ; SS = 0x2000 (segmento de pilha)
    mov sp, 0xFFFF       ; Inicializa o ponteiro de pilha no topo do segmento

    ; --------------------------------------------------------------
    ; Cópia do BPB (BIOS Parameter Block)
    ; --------------------------------------------------------------
    ; O BPB está localizado no setor de boot (0x7C00).
    ; Aqui copiamos 59 bytes a partir de 0x7C03 para a área de dados
    ; do kernel, preservando as informações do sistema de arquivos.
    ; --------------------------------------------------------------
    push ds              ; Salva DS atual na pilha
    push es              ; Salva ES atual na pilha

    mov ax, 0x0000       ; DS = 0x0000 (onde está o setor de boot)
    mov ds, ax
    mov ax, 0x2000       ; ES = 0x2000 (área de dados do kernel)
    mov es, ax

    mov si, 0x7C03       ; SI aponta para o início do BPB no setor de boot
    mov di, bpb_data_start ; DI aponta para onde o BPB será copiado
    mov cx, 59           ; Número de bytes a copiar
    rep movsb            ; Copia CX bytes de DS:SI para ES:DI

    pop es               ; Restaura ES original
    pop ds               ; Restaura DS original

    call kernel_login_check     ; Chama a rotina de verificação de login.
                                ; O endereço de retorno é empilhado e,
                                ; ao final da rotina, um RET trará o fluxo
                                ; de volta para a próxima instrução.

    ; Exibe mensagem de boas-vindas
    call welcome_show           ; Mostra a tela inicial (ASCII art).
                                ; Também usa CALL/RET para manter o fluxo.

    mov si, msg_welcome         ; Carrega em SI o endereço da string msg_welcome.
                                ; A convenção é que print_string lê a partir de SI.

    call print_string           ; Imprime a string apontada por SI até encontrar
                                ; o terminador definido (ex: '$' ou 0).

; --------------------------------------------------------------
; Loop Principal do Shell
; --------------------------------------------------------------
shell_loop:
    ; Exibe o prompt do shell
    mov si, msg_prompt          ; SI aponta para a string do prompt (ex: "FEP-OS> ").
    call print_string           ; Exibe o prompt na tela.

    ; Inicializa o buffer de comando
    mov di, command_buffer      ; DI aponta para o início do buffer de entrada.
                                ; Cada caractere digitado será armazenado aqui.

    mov cx, 0                   ; Zera CX, que será usado como contador de caracteres.
                                ; Cada tecla válida incrementa CX, permitindo saber
                                ; o tamanho do comando digitado.

; --------------------------------------------------------------
; Rotina de Leitura de Entrada do Usuário
; --------------------------------------------------------------
read_loop:
    mov ah, 0x00              ; AH = 0 → Função 0 do INT 16h (BIOS Teclado).
                              ; Essa função espera até que uma tecla seja pressionada
                              ; e retorna o código ASCII em AL e o código de varredura em AH.

    int 0x16                  ; Chama a interrupção de teclado.
                              ; Após a execução:
                              ; - AL contém o caractere ASCII da tecla.
                              ; - AH contém o scan code da tecla.

    cmp al, 0x0D              ; Compara AL com 0x0D (Enter / Carriage Return).
    je process_key_enter       ; Se AL == 0x0D, salta para a rotina que processa o comando.

    cmp al, 0x08              ; Compara AL com 0x08 (Backspace).
    je handle_backspace        ; Se AL == 0x08, salta para a rotina que trata o backspace.

    ; ----------------------------------------------------------
    ; Correção de Overflow no Buffer
    ; ----------------------------------------------------------
    ; Aqui verificamos se ainda há espaço no buffer de comando.
    ; Mantemos sempre 1 byte livre para o terminador nulo (0).
    ; Se o buffer estiver cheio, a tecla é ignorada e voltamos
    ; para o loop de leitura.
    ; ----------------------------------------------------------
    mov bx, COMMAND_BUFFER_SIZE ; BX = tamanho total do buffer.
    dec bx                      ; BX = tamanho máximo permitido - 1.
    cmp cx, bx                  ; CX contém a quantidade de caracteres já digitados.
    jge read_loop               ; Se CX >= BX, ignora a tecla e volta a ler outra.

    ; Exibe o caractere digitado na tela
    call print_char             ; Mostra o caractere armazenado em AL no vídeo.

    ; Armazena o caractere no buffer
    mov [di], al                ; Salva o caractere em AL no endereço apontado por DI.
    inc di                      ; Avança o ponteiro DI para a próxima posição do buffer.
    inc cx                      ; Incrementa o contador de caracteres digitados.

    jmp read_loop               ; Volta para o início do loop para ler a próxima tecla.

; --------------------------------------------------------------
; Tratamento do Backspace
; --------------------------------------------------------------
handle_backspace:
    cmp cx, 0                 ; Verifica se CX == 0 (nenhum caractere no buffer).
                              ; Se não há nada para apagar, não faz sentido
                              ; processar backspace → ignora.
    je read_loop              ; Se CX == 0, volta para o loop de leitura.

    dec di                    ; Retrocede o ponteiro do buffer (DI).
                              ; Isso "aponta" para a última posição escrita.
    dec cx                    ; Decrementa o contador de caracteres digitados.

    ; ----------------------------------------------------------
    ; Sequência para apagar o caractere da tela
    ; ----------------------------------------------------------
    mov al, 0x08              ; ASCII 0x08 = Backspace → move o cursor 1 posição para trás.
    call print_char

    mov al, ' '               ; Escreve um espaço em branco no lugar do caractere.
    call print_char

    mov al, 0x08              ; Mais um backspace → move o cursor novamente para trás,
                              ; reposicionando-o corretamente após apagar.
    call print_char

    jmp read_loop             ; Volta ao loop principal de leitura de teclas.

; --------------------------------------------------------------
; Tratamento da Tecla Enter
; --------------------------------------------------------------
process_key_enter:
    ; Quando o usuário pressiona Enter, não saltamos direto para o shell_loop.
    ; Primeiro chamamos a rotina que processa o comando digitado.
    call process_command       ; Executa a rotina que interpreta o comando no buffer.
                               ; Essa rotina deve terminar com RET, voltando aqui.

    jmp shell_loop             ; Depois de processar, volta ao início do shell:
                               ; mostra o prompt novamente e espera novo comando.
	
; --------------------------------------------------------------
; Loop de Espera (caso o sistema trave ou finalize)
; --------------------------------------------------------------
hang:
    jmp hang                  ; Loop infinito.
                              ; Essa rotina é usada como "estado final" do kernel.
                              ; Se o sistema travar ou encerrar, ele entra aqui
                              ; e fica preso para sempre, evitando execução de lixo
                              ; ou instruções inválidas na memória.

; ==================================================================
; Inclusão dos Módulos (na ordem correta)
; ==================================================================
%include "kernel/data.asm"       ; Definições de dados globais, buffers e variáveis.
%include "drivers/cursor.asm"    ; Rotinas para manipulação do cursor de texto.
%include "kernel/login.asm"      ; Implementação da rotina de login do sistema.
%include "kernel/welcome.asm"    ; Tela de boas-vindas (ASCII art, mensagens iniciais).
%include "drivers/video.asm"     ; Funções de vídeo: print_char, print_string, etc.
%include "lib/string.asm"        ; Funções auxiliares de manipulação de strings.
%include "lib/stdlib.asm"        ; Funções utilitárias (conversões, utilidades gerais).
%include "fs/fat12/fat.asm"      ; Manipulação da FAT12 (File Allocation Table).
%include "fs/fat12/rootdir.asm"  ; Rotinas para acessar o diretório raiz.
%include "fs/fat12/file_ops.asm" ; Operações básicas de arquivos (abrir, ler, etc.).
%include "fs/fat12/filename.asm" ; Manipulação de nomes de arquivos (8.3).
%include "fs/fat12/directory.asm"; Rotinas para manipular diretórios.
%include "fs/fat12/listing.asm"  ; Listagem de arquivos e diretórios.
%include "drivers/disk.asm"      ; Rotinas de acesso direto ao disco (BIOS INT 13h).
%include "shell/shell.asm"       ; Implementação do shell principal (loop de comandos).
%include "shell/commands/cat.asm"      ; Exibe conteúdo de arquivos.
%include "shell/commands/cp.asm"       ; Copia arquivos.
%include "shell/commands/reboot.asm"   ; Reinicia o sistema.
%include "shell/commands/echo.asm"     ; Exibe mensagens no terminal.
%include "shell/commands/ls.asm"       ; Lista arquivos e diretórios.
%include "shell/commands/rm.asm"       ; Remove arquivos.
%include "shell/commands/touch.asm"    ; Cria arquivos vazios.
%include "shell/commands/mem.asm"      ; Mostra uso de memória.
%include "shell/commands/clock.asm"    ; Mostra o relógio do sistema.
%include "shell/commands/exec.asm"     ; Executa programas externos.
%include "shell/commands/wc.asm"       ; Conta palavras/linhas/caracteres.
%include "shell/commands/grep.asm"     ; Busca padrões em arquivos.
%include "shell/commands/tail.asm"     ; Mostra últimas linhas de um arquivo.
%include "shell/commands/head.asm"     ; Mostra primeiras linhas de um arquivo.
%include "shell/commands/more.asm"     ; Paginação de arquivos longos.
%include "shell/commands/hexdump.asm"  ; Exibe conteúdo em formato hexadecimal.
%include "shell/commands/ver.asm"      ; Mostra versão do sistema.
%include "shell/commands/ajuda.asm"    ; Lista de ajuda com comandos disponíveis.
%include "shell/commands/cls.asm"      ; Limpa a tela.
%include "shell/commands/pwd.asm"      ; Mostra diretório atual.
%include "shell/commands/df.asm"       ; Mostra espaço livre em disco.
%include "shell/commands/mv.asm"       ; Move/renomeia arquivos.
%include "shell/commands/shutdown.asm" ; Desliga o sistema.
%include "shell/commands/fatdump.asm"  ; Mostra conteúdo bruto da FAT.
%include "shell/commands/mkdir.asm"    ; Cria diretórios.
%include "shell/commands/rmdir.asm"    ; Remove diretórios.
%include "shell/commands/cd.asm"       ; Muda de diretório.
%include "shell/commands/edit.asm"     ; Editor de texto simples.