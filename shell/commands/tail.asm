
execute_tail:
    pusha
    push ds
    push es

    ; 1. Validar Argumento
    mov si, bp
    cmp byte [si], 0
    je .tail_usage

    ; 2. Carregar Ficheiro
    mov ax, bp
    mov cx, 0x8000
    call load_file
    jc .tail_file_not_found
    
    mov bp, bx ; BP = Tamanho 16-bit (guardado)
    mov cx, bx ; CX = Tamanho 16-bit (contador Passagem 1)

    ; 3. PASSAGEM 1: Contar o total de linhas
    mov word [tail_total_lines], 0
    mov ax, 0x0800
    mov es, ax
    mov si, 0x0000
    
    cmp cx, 0
    je .tail_check_last_line ; Ficheiro vazio

    mov ah, 0
.tail_pass1_loop:
    mov al, [es:si]
    inc si
    
    cmp al, 0x0D
    je .tail_p1_next ; Ignora CR
    
    cmp al, 0x0A
    jne .tail_p1_not_lf
    
    inc word [tail_total_lines]
    mov ah, 1
    jmp .tail_p1_next
    
.tail_p1_not_lf:
    mov ah, 0

.tail_p1_next:
    dec cx
    cmp cx, 0
    jne .tail_pass1_loop

.tail_check_last_line:
    cmp bp, 0
    je .tail_calc_start
    cmp ah, 0
    jne .tail_calc_start
    inc word [tail_total_lines]

.tail_calc_start:
    ; 4. Calcular onde começar a Passagem 2
    mov ax, [tail_total_lines]
    cmp ax, 10
    jbe .tail_start_at_zero
    
    sub ax, 10
    mov word [tail_start_line], ax
    jmp .tail_pass2_init

.tail_start_at_zero:
    mov word [tail_start_line], 0

.tail_pass2_init:
    ; 5. PASSAGEM 2: Imprimir as linhas certas
    mov cx, bp ; Recarrega CX com o tamanho original (guardado em BP)
    mov word [tail_current_line], 0
    
    mov ax, 0x0800
    mov es, ax
    mov si, 0x0000 ; Reseta ponteiro de leitura
    mov di, line_buffer ; Reseta buffer de linha
    
    cmp cx, 0
    je .tail_exit

.tail_pass2_loop:
    ; Loop de leitura (igual ao grep/head)
    cmp cx, 0
    je .tail_p2_loop_done

    mov al, [es:si]
    inc si
    dec cx

    cmp al, 0x0D
    je .tail_pass2_loop

    cmp al, 0x0A
    je .tail_p2_process_line
    
    mov bx, di
    sub bx, line_buffer
    cmp bx, 255
    jge .tail_p2_process_line

    mov byte [di], al
    inc di
    
    cmp cx, 0 ; Fim do ficheiro (sem \n)?
    je .tail_p2_process_line ; Se sim, processa o que temos
    
    jmp .tail_pass2_loop

.tail_p2_process_line:
    mov byte [di], 0
    cmp di, line_buffer
    je .tail_p2_reset_and_continue

    ; --- LÓGICA DO TAIL ---
    mov ax, [tail_current_line]
    cmp ax, [tail_start_line]
    jl .tail_p2_skip_print ; Se (current < start), não imprime

    ; ***** INÍCIO DA CORREÇÃO *****
    ; Salva o estado do loop (SI, CX, ES)
    push si
    push cx
    push es
    
    ; OK, imprime esta linha
    mov si, line_buffer
    call print_string
    call print_newline

    ; Restaura o estado do loop
    pop es
    pop cx
    pop si
    ; ***** FIM DA CORREÇÃO *****
    
    jmp .tail_p2_reset_and_continue

.tail_p2_skip_print:
    inc word [tail_current_line]

.tail_p2_reset_and_continue:
    mov di, line_buffer
    jmp .tail_pass2_loop

.tail_p2_loop_done:
    ; (Fim do ficheiro chegou através de CX=0)
    jmp .tail_exit
    
.tail_usage:
    mov si, tail_usage_msg
    call print_string
    jmp .tail_exit

.tail_file_not_found:
    mov si, cat_notfound_msg
    call print_string
    
.tail_exit:
    pop es
    pop ds
    popa
    ret


; --------------------------------------------------------------
; Mensagens auxiliares para "tail"
; --------------------------------------------------------------
; Objetivo:
;   Exibir instruções de uso quando o usuário fornece argumentos inválidos.
;   Usadas para orientar sobre a sintaxe correta dos comandos.
; --------------------------------------------------------------
tail_usage_msg:     db 'Uso: tail <arquivo>', 13, 10, 0

; --------------------------------------------------------------
; Variáveis globais para "tail"
; --------------------------------------------------------------
; Objetivo:
;   Controlar o fluxo de leitura de linhas no comando "tail".
;   O comando geralmente tem duas passagens:
;     1. Contagem total de linhas
;     2. Impressão das últimas N linhas
; --------------------------------------------------------------
tail_total_lines:   dw 0  ; Total de linhas encontradas (Passagem 1)
tail_current_line:  dw 0  ; Linha atual sendo processada (Passagem 2)
tail_start_line:    dw 0  ; Linha onde começa a impressão (últimas N)
