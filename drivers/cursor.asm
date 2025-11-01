; ========================================================================
; src/drivers/cursor.asm - Rotinas utilitárias para manipulação do cursor
; ========================================================================

BITS 16

; ---------------------------------------------------------------
; set_cursor(row, col)
; Entrada: DH = linha (0–24), DL = coluna (0–79)
; ---------------------------------------------------------------
set_cursor:
    push ax
    push bx
    mov ah, 02h
    xor bh, bh        ; página 0
    int 10h
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------
; get_cursor -> retorna em DH/DL
; Saída: DH = linha, DL = coluna
; ---------------------------------------------------------------
get_cursor:
    push ax
    push bx
    mov ah, 03h
    xor bh, bh
    int 10h
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------
; cursor_home -> posiciona em (0,0)
; ---------------------------------------------------------------
cursor_home:
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000 
    int 0x10
    ret

; ---------------------------------------------------------------
; cursor_left – move uma coluna para a esquerda
; ---------------------------------------------------------------
cursor_left:
    call get_cursor
    cmp dl, 0
    je .done
    dec dl
    call set_cursor
.done:
    ret

; ---------------------------------------------------------------
; cursor_right – move uma coluna para a direita
; ---------------------------------------------------------------
cursor_right:
    call get_cursor
    cmp dl, 79
    je .done
    inc dl
    call set_cursor
.done:
    ret

; ---------------------------------------------------------------
; cursor_up – move uma linha para cima
; ---------------------------------------------------------------
cursor_up:
    call get_cursor
    cmp dh, 0
    je .done
    dec dh
    call set_cursor
.done:
    ret

; ---------------------------------------------------------------
; cursor_down – move uma linha para baixo
; ---------------------------------------------------------------
cursor_down:
    call get_cursor
    cmp dh, 24
    je .done
    inc dh
    call set_cursor
.done:
    ret

; ---------------------------------------------------------------
; cursor_hide / cursor_show
; ---------------------------------------------------------------
cursor_hide:
    push ax
    mov ah, 01h
    mov ch, 20h       ; start line > end line = invisível
    mov cl, 0
    int 10h
    pop ax
    ret

cursor_show:
    push ax
    mov ah, 01h
    mov ch, 06h       ; forma padrão (linha inicial)
    mov cl, 07h       ; linha final
    int 10h
    pop ax
    ret
