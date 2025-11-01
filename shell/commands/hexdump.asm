
execute_hexdump:
    pusha
    push ds
    push es

    ; 1. Validar Argumento
    mov si, bp
    cmp byte [si], 0
    je .hexdump_usage ; Jump to local label

    ; 2. Load File (!!! USANDO 0x8000 !!!)
    mov ax, bp
    mov cx, 0x8000 ; <<< ENDEREÇO ORIGINAL BAIXO
    call load_file
    jc .hexdump_not_found ; Jump to local label
    mov cx, bx ; CX = Size 16-bit (byte counter)

    ; 3. Prepare Loop (!!! USANDO 0x0800 !!!)
    mov ax, 0x0800 ; <<< SEGMENTO ORIGINAL BAIXO
    mov es, ax
    
    mov bx, 0x0000 ; BX = File read pointer (ES:BX)
    
    mov bp, 0 ; BP = Offset counter (para "0000:", "0010:")
    
.hexdump_main_loop:
    cmp cx, 0
    je .hexdump_exit ; Jump to local label

    ; --- Start of a new line ---
    mov di, 0 ; DI = byte counter for this line (0-15)

    ; Imprime o offset (ex: "0000")
    push ax 
    push dx
    mov ax, bp
    call print_hex_word 
    
    mov si, hexdump_colon_msg ; Print ": " 
    call print_string
    pop dx
    pop ax

.hexdump_hex_loop:
    cmp di, 16 
    je .hexdump_ascii_part ; Jump to local label

    cmp cx, 0 
    je .hexdump_partial_line ; Jump to local label

    ; --- Process 1 byte ---
    mov al, [es:bx] ; Lê do ficheiro usando BX
    inc bx          ; Avança ponteiro do ficheiro BX
    
    dec cx
    inc bp ; Incrementa offset global

    ; Imprime a parte HEX ("4F ")
    push ax
    call print_hex_byte 
    mov si, hexdump_space_msg 
    call print_string
    pop ax
    
    ; Guarda a parte ASCII no line_buffer
    cmp al, 0x20 
    jl .non_printable
    cmp al, 0x7E 
    jg .non_printable
    
.printable:
    mov [line_buffer+di], al
    jmp .next_byte_in_line
.non_printable:
    mov byte [line_buffer+di], '.'
    jmp .next_byte_in_line ; Garante que este jump está aqui
    
.next_byte_in_line:
    inc di
    jmp .hexdump_hex_loop

.hexdump_ascii_part:
    mov byte [line_buffer+16], 0 
    
    mov si, hexdump_gap_msg 
    call print_string
    mov si, line_buffer     
    call print_string
    call print_newline
    
    jmp .hexdump_main_loop 

.hexdump_partial_line:
    mov bx, di ; Salva o n.º de bytes lidos em BX

.pad_loop:
    cmp di, 16
    je .print_partial_ascii
    
    mov si, hexdump_spaces_msg 
    call print_string
    inc di
    jmp .pad_loop

.print_partial_ascii:
    mov byte [line_buffer+bx], 0 ; Termina usando BX
    
    mov si, hexdump_gap_msg 
    call print_string
    mov si, line_buffer     
    call print_string
    call print_newline
    
    jmp .hexdump_exit

.hexdump_usage: ; Define local label
    mov si, hexdump_usage_msg
    call print_string
    jmp .hexdump_exit ; Jump to common exit

.hexdump_not_found: ; Define local label
    mov si, cat_notfound_msg
    call print_string
    ; Cai para o exit
    
.hexdump_exit: ; Define local label
    pop es
    pop ds
    popa
    ret

; --------------------------------------------------------------
; Mensagens auxiliares para "hexdump"
; --------------------------------------------------------------
; Objetivo:
;   Exibir instruções e formatar a saída do comando "hexdump",
;   que mostra o conteúdo de arquivos em formato hexadecimal.
;
; Observações:
;   - As mensagens incluem espaços e separadores para alinhamento visual.
;   - CR (13) + LF (10) representam quebra de linha.
; --------------------------------------------------------------
hexdump_usage_msg: db 'Uso: hexdump <arquivo>', 13, 10, 0 ; Instrução de uso
hexdump_colon_msg: db ': ', 0                             ; Separador após endereço
hexdump_space_msg: db ' ', 0                              ; Espaço simples
hexdump_spaces_msg: db '   ', 0                           ; Espaço triplo para alinhamento
hexdump_gap_msg:    db '  ', 0                            ; Espaço duplo entre hex e ASCII
hexdump_current_offset dw 0                               ; Guarda o offset atual (0000, 0010, etc.)
