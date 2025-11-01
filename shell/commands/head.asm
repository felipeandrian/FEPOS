
execute_head:
    pusha
    push ds
    push es

    ; 1. Validar Argumento
    mov si, bp
    cmp byte [si], 0
    je .head_usage

    ; 2. Carregar Ficheiro
    mov ax, bp
    mov cx, 0x8000
    call load_file
    jc .head_file_not_found
    mov cx, bx ; CX = Tamanho 16-bit (contador de loop)

    ; 3. Preparar Loop
    mov ax, 0x0800
    mov es, ax
    mov si, 0x0000
    mov di, line_buffer
    
    mov bp, 0 ; BP = Contador de linhas impressas
    
.head_loop:
    ; Verifica se terminámos os bytes
    cmp cx, 0
    je .head_loop_done 

    mov al, [es:si] ; Lê byte
    inc si
    dec cx          ; Decrementa contador

    cmp al, 0x0D ; Ignora CR
    je .head_loop

    cmp al, 0x0A ; É LF (Newline)?
    je .head_process_line
    
    ; É char normal. Adiciona ao buffer.
    mov bx, di
    sub bx, line_buffer
    cmp bx, 255 ; Buffer cheio?
    jge .head_process_line ; Se sim, processa

    mov byte [di], al
    inc di
    
    cmp cx, 0 ; Fim do ficheiro (sem \n)?
    je .head_process_line ; Se sim, processa o que temos
    
    jmp .head_loop ; Continua a ler bytes

.head_process_line:
    mov byte [di], 0    ; Termina a string

    ; Verifica se a linha estava vazia
    cmp di, line_buffer 
    je .head_reset_and_continue ; Se sim, não imprime, só reseta

    ; ***** INÍCIO DA CORREÇÃO *****
    ; Salva o estado do loop (SI, CX, ES) antes de os corrompermos
    push si
    push cx
    push es
    
    ; --- LÓGICA DO HEAD ---
    mov si, line_buffer
    call print_string
    call print_newline
    
    inc bp ; Incrementa contador de linhas
    
    ; Restaura o estado do loop
    pop es
    pop cx
    pop si
    ; ***** FIM DA CORREÇÃO *****
    
    cmp bp, 10 ; Chegou a 10?
    je .head_exit ; Se sim, TERMINA TUDO.

.head_reset_and_continue:
    mov di, line_buffer ; Reseta DI para a próxima linha
    jmp .head_loop      ; Volta ao loop de leitura de bytes

.head_loop_done:
    ; (Fim do ficheiro chegou através de CX=0)
    jmp .head_exit

.head_usage:
    mov si, head_usage_msg
    call print_string
    jmp .head_exit

.head_file_not_found:
    mov si, cat_notfound_msg
    call print_string
    
.head_exit:
    pop es
    pop ds
    popa
    ret
	
; --------------------------------------------------------------
; Mensagens auxiliares para "head" e "tail"
; --------------------------------------------------------------
; Objetivo:
;   Exibir instruções de uso quando o usuário fornece argumentos inválidos.
;   Usadas para orientar sobre a sintaxe correta dos comandos.
; --------------------------------------------------------------
head_usage_msg:     db 'Uso: head <arq>', 13, 10, 0


