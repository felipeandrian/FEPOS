
execute_grep:
    pusha
    push ds
    push es

    ; 1. Validar Argumentos (Pattern e Filename)
    mov si, bp
    call string_parse ; Divide a string: AX=arg1, BX=arg2

    cmp ax, 0 ; Não há pattern?
    je .grep_usage
    cmp bx, 0 ; Não há filename?
    je .grep_usage

    mov [grep_pattern_ptr], ax ; Salva o ponteiro para o pattern (AX)

    ; 2. Carregar o Ficheiro
    mov ax, bx          ; AX = ponteiro para nome do arquivo (BX)
    mov cx, 0x8000      ; Endereço linear de carregamento
    call load_file
    jc .grep_file_not_found
    ; load_file RETORNA O TAMANHO (16-bit) EM BX
    
    mov cx, bx          ; CX = Tamanho 16-bit (contador de loop)

    ; 3. Preparar Loop de Análise (Linha por Linha)
    mov ax, 0x0800
    mov es, ax          ; ES = 0x0800 (segmento do buffer do ficheiro)
    mov si, 0x0000      ; SI = ponteiro de leitura (fonte)
    
    mov di, line_buffer ; DI = ponteiro de escrita (buffer da linha)
    
.grep_loop:
    ; Verifica se terminámos
    cmp cx, 0
    je .grep_loop_done 

    mov al, [es:si] ; Lê 1 byte do ficheiro
    inc si
    dec cx          ; Decrementa contador manualmente

    cmp al, 0x0D ; Ignora CR (Carriage Return)
    je .grep_loop

    cmp al, 0x0A ; É LF (Newline)?
    je .grep_process_line
    
    ; É char normal. Adiciona ao buffer.
    mov bx, di
    sub bx, line_buffer
    cmp bx, 255 ; Buffer cheio? (256 bytes)
    jge .grep_process_line ; Se sim, processa

    mov [di], al
    inc di
    jmp .grep_loop ; Continua a ler bytes

; ------------------------------------------------------------------
; ***** INÍCIO DA CORREÇÃO *****
; ------------------------------------------------------------------
.grep_process_line:
    ; Linha acabou (por \n ou buffer cheio)
    mov byte [di], 0    ; Termina a string no line_buffer
    
    ; Verifica se a linha estava vazia *ANTES* de resetar DI
    cmp di, line_buffer 
    je .grep_reset_and_continue ; Se DI == line_buffer, a linha estava vazia.

    ; A linha não está vazia, vamos processá-la
    push si ; Salva ponteiro do ficheiro
    push cx ; Salva contador do ficheiro
    push es ; Salva segmento do ficheiro
    
    mov si, line_buffer
    mov di, [grep_pattern_ptr]
    call string_search
    
    ; Se encontrou (CF=0), imprime
    jnc .grep_print_line
    
    ; Se não encontrou, só restaura e continua
    pop es
    pop cx
    pop si
    jmp .grep_reset_and_continue

.grep_print_line:
    ; Encontrou!
    mov si, line_buffer
    call print_string
    call print_newline
    
    ; Restaura o estado do loop
    pop es
    pop cx
    pop si
    ; JMP para o reset

.grep_reset_and_continue:
    mov di, line_buffer ; Reseta ponteiro DI para a próxima linha
    jmp .grep_loop      ; Continua a ler o ficheiro
; ------------------------------------------------------------------
; ***** FIM DA CORREÇÃO *****
; ------------------------------------------------------------------

.grep_loop_done:
    ; Processa a última linha (caso o ficheiro não termine com \n)
    mov byte [di], 0
    cmp di, line_buffer
    je .grep_exit
    
    mov si, line_buffer
    mov di, [grep_pattern_ptr]
    call string_search
    jc .grep_exit
    
    mov si, line_buffer
    call print_string
    call print_newline
    jmp .grep_exit

.grep_usage:
    mov si, grep_usage_msg
    call print_string
    jmp .grep_exit

.grep_file_not_found:
    mov si, cat_notfound_msg
    call print_string
    
.grep_exit:
    pop es
    pop ds
    popa
    ret

; --------------------------------------------------------------
; Mensagens auxiliares para o comando "grep"
; --------------------------------------------------------------
; Objetivo:
;   Exibir instrução de uso correta para o comando "grep".
;   O comando busca padrões em arquivos linha a linha.
; --------------------------------------------------------------
grep_usage_msg: db 'Uso: grep <pattern> <arq>', 13, 10, 0


; --------------------------------------------------------------
; Buffers de Trabalho
; --------------------------------------------------------------
; Objetivo:
;   Armazenar dados temporários durante a execução de comandos.
;   Inclui ponteiro para padrão de busca e buffer de linha.
; --------------------------------------------------------------
grep_pattern_ptr: dw 0      ; Ponteiro para o padrão (agulha)
line_buffer:      resb 256  ; Buffer para armazenar uma linha (até 255 chars)