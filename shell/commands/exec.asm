
execute_exec:
    pusha
    push ds
    push es

    ; 1. Validar Argumento (Nome do Ficheiro)
    mov si, bp
    cmp byte [si], 0
    je .exec_usage

    ; 2. Carregar o Ficheiro de Script
    mov ax, bp          ; AX = ponteiro para nome do arquivo
    mov cx, 0x9000      ; Endereço linear de carregamento (36KB)
    call load_file
    jc .exec_not_found
    ; load_file retorna tamanho 16-bit em BX
    
    ; 3. Configurar Variáveis Globais do Script
    ; (load_file carrega para ES:BX, mas nós calculámos 0x9000)
    mov ax, 0x0900
    
    ; ***** INÍCIO DA CORREÇÃO *****
    mov word [script_buffer_es], ax
    mov word [script_buffer_si], 0
    mov word [script_bytes_left], bx ; BX = Tamanho 16-bit
    ; ***** FIM DA CORREÇÃO *****

.exec_loop:
    ; 4. Ler uma linha do script
    call read_line_from_script
    jc .exec_done ; Se Carry=1, script terminou

    ; 5. Processar a linha (ecoar e executar)
    ; (A linha já está no command_buffer)
    
    ; Opcional: Ecoar o comando na tela
    mov si, msg_prompt ; Mostra '> '
    call print_string
    mov si, command_buffer
    call print_string
    call print_newline
    
    ; Processa o comando
    call process_command
    
    jmp .exec_loop ; Vai para a próxima linha

.exec_done:
    pop es
    pop ds
    popa
    ret ; Retorna para o shell_loop (que foi chamado pelo kernel)

.exec_usage:
    mov si, exec_usage_msg
    call print_string
    pop es
    pop ds
    popa
    ret

.exec_not_found:
    mov si, exec_not_found_msg
    call print_string
    pop es
    pop ds
    popa
    ret

; ------------------------------------------------------------------
; read_line_from_script
; Lê uma linha do buffer do script (ES:SI) para o command_buffer
; Saída:
;   CF = 0 (Sucesso), command_buffer preenchido
;   CF = 1 (Fim de Ficheiro)
; ------------------------------------------------------------------
read_line_from_script:
    pusha
    
    mov di, command_buffer      ; Destino: command_buffer
    mov es, [script_buffer_es]
    mov si, [script_buffer_si]
    mov cx, [script_bytes_left]

.read_byte_loop:
    cmp cx, 0
    je .eof ; Se bytes_left=0, fim de ficheiro

    mov al, [es:si]
    inc si
    dec cx

    cmp al, 0x0D ; Ignora CR
    je .read_byte_loop
    
    cmp al, 0x0A ; É LF (fim de linha)?
    je .eol ; Se sim, fim da linha

    mov byte [di], al ; Copia char para o command_buffer
    inc di
    jmp .read_byte_loop

.eol:
    ; Fim da linha, termina a string
    mov byte [di], 0
    
    ; Salva o progresso
    mov word [script_buffer_es], es
    mov word [script_buffer_si], si
    mov word [script_bytes_left], cx
    
    popa
    clc ; Sucesso (CF=0)
    ret

.eof:
    ; Fim do ficheiro
    ; Se DI > command_buffer, significa que o ficheiro terminou
    ; sem um newline (última linha). Processa-a.
    cmp di, command_buffer
    je .eof_final ; Se buffer vazio, FIM

    jmp .eol ; Processa a última linha

.eof_final:
    popa
    stc ; Fim de ficheiro (CF=1)
    ret

; --------------------------------------------------------------
; Mensagens auxiliares para o comando "exec"
; --------------------------------------------------------------
; Objetivo:
;   Informar ao usuário como usar o comando "exec" corretamente,
;   ou alertar quando o script não foi encontrado.
; --------------------------------------------------------------
exec_usage_msg:     db 'Uso: exec <arq>', 13, 10, 0
exec_not_found_msg: db 'Script arquivo nao encontrado.', 13, 10, 0

; --------------------------------------------------------------
; Variáveis globais para o leitor de scripts
; --------------------------------------------------------------
; Objetivo:
;   Controlar a leitura sequencial de um script carregado na memória.
;   Usado pelo comando "exec" para interpretar linha por linha.
; --------------------------------------------------------------
script_buffer_es:   dw 0 ; Segmento onde o script está carregado
script_buffer_si:   dw 0 ; Offset atual (ponteiro de leitura)
script_bytes_left:  dw 0 ; Quantidade de bytes restantes para leitura