
; ============================================================
; fatdump -- lê a FAT e imprime os primeiros 16 clusters
; ============================================================

fatdump:
    pusha
    push ds
    push es

    ; 1. Ler a FAT para o buffer
    call disk_read_fat
    jc .fail

    ; 2. Configuração inicial
    mov si, 2          ; cluster inicial
    mov cx, 23         ; quantos clusters mostrar

.next:
    ; pos = (3*cluster)/2
    mov ax, si
    xor dx, dx
    mov bx, 3
    mul bx
    mov bx, 2
    div bx             ; AX = pos, DX = paridade (0=par,1=ímpar)

    mov di, disk_buffer
    add di, ax
    mov ax, [di]

    test dx, dx
    jz .even
    shr ax, 4          ; ímpar → bits altos
    jmp .got
.even:
    and ax, 0x0FFF     ; par → bits baixos
.got:

    ; imprime: cluster <SI> = <AX>
    push ax
    mov ax, si
    call print_word_dec
    mov al, '='
    call putc
    mov al, ' '
    call putc
    pop ax
    call print_word_dec

    ; quebra de linha
    mov al, 13
    call putc
    mov al, 10
    call putc

    inc si
    loop .next
    jmp .done

.fail:
    mov si, msg_fail2
    call print_string

.done:
    pop es
    pop ds
    popa
    ret

; ------------------------------------------------------------
; print_word_dec -- imprime AX em decimal
; ------------------------------------------------------------
print_word_dec:
    pusha
    mov cx, 0
.pwd1:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .pwd1
.pwd2:
    pop dx
    add dl, '0'
    mov al, dl
    call putc
    loop .pwd2
    popa
    ret

; ------------------------------------------------------------
; putc -- imprime caractere em AL
; ------------------------------------------------------------
putc:
    pusha
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    popa
    ret

msg_fail2 db 'Erro ao ler FAT',13,10,0

