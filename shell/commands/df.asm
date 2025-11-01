; ============================================================
; df -- mostra espaço total, usado e livre em KB (FAT12 1.44MB)
; também imprime número de clusters livres/ocupados
; ============================================================

execute_df:
    pusha
    call disk_read_fat
    jc .fail

    ; --------------------------------------------------------
    ; 1) calcular total direto do BPB
    ; --------------------------------------------------------
    mov ax, [bpb_total_sectors]
    mov bx, [bpb_bytes_per_sector]
    mul bx                  ; DX:AX = total bytes
    mov bx, 1024
    div bx                  ; AX = total KB
    mov [total_kb], ax

    ; --------------------------------------------------------
    ; 2) zera contadores em memória
    ; --------------------------------------------------------
    mov word [livre_clusters], 0
    mov word [usado_clusters], 0

    mov si, 2               ; cluster inicial
.next:
    cmp si, 2849            ; último cluster +1 (2..2848)
    jge .done

    ; --------------------------------------------------------
    ; extrair entrada FAT12 para cluster SI
    ; --------------------------------------------------------
    mov ax, si
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                  ; AX = pos, DX = paridade
    mov di, disk_buffer
    add di, ax

    mov bl, [di]            ; b0
    mov bh, [di+1]          ; b1
    mov dl, [di+2]          ; b2

    cmp dx, 0
    jne .odd

    ; ---- cluster par ----
    movzx ax, bl
    movzx cx, bh
    and cx, 0x0F
    shl cx, 8
    or ax, cx
    jmp .got

.odd:
    ; ---- cluster ímpar ----
    movzx ax, bh
    and ax, 0xF0
    shr ax, 4
    movzx cx, dl
    shl cx, 4
    or ax, cx

.got:
    cmp ax, 0
    je .livre
    cmp ax, 0xFF8
    jb .ocupado
.ocupado:
    inc word [usado_clusters]
    jmp .cont
.livre:
    inc word [livre_clusters]
.cont:
    inc si
    jmp .next

.done:
    ; --------------------------------------------------------
    ; 3) calcular bytes por cluster
    ; --------------------------------------------------------
    mov ax, [bpb_bytes_per_sector]
    mov cx, [bpb_sectors_per_cluster]
    mul cx
    mov si, ax              ; SI = bytes por cluster

    ; --------------------------------------------------------
    ; 4) converter livres em KB
    ; --------------------------------------------------------
    mov ax, [livre_clusters]
    mul si
    mov bx, 1024
    div bx
    mov [livre_kb], ax

    ; --------------------------------------------------------
    ; 5) converter usados em KB
    ; --------------------------------------------------------
    mov ax, [usado_clusters]
    mul si
    mov bx, 1024
    div bx
    mov [usado_kb], ax

    ; --------------------------------------------------------
    ; 6) imprimir resultado
    ; --------------------------------------------------------
    mov si, msg_total
    call print_string
    mov ax, [total_kb]
    call print_word_dec
    mov si, msg_kb
    call print_string

    mov si, msg_used
    call print_string
    mov ax, [usado_kb]
    call print_word_dec
    mov si, msg_kb
    call print_string

    mov si, msg_free
    call print_string
    mov ax, [livre_kb]
    call print_word_dec
    mov si, msg_kb
    call print_string

    ; debug clusters
    mov si, msg_usedc
    call print_string
    mov ax, [usado_clusters]
    call print_word_dec
    mov si, msg_freec
    call print_string
    mov ax, [livre_clusters]
    call print_word_dec
    call print_newline

    popa
    ret

.fail:
    mov si, msg_fail
    call print_string
    popa
    ret
	
; ------------------------------------------------------------
; variáveis auxiliares 
; ------------------------------------------------------------
total_kb        resw 1
usado_kb        resw 1
livre_kb        resw 1
usado_clusters  resw 1
livre_clusters  resw 1

; ------------------------------------------------------------
; mensagens
; ------------------------------------------------------------
msg_total  db 'Total: ',0
msg_used   db 'Usado: ',0
msg_free   db 'Livre: ',0
msg_kb     db ' KB',13,10,0
msg_usedc  db 'Clusters usados: ',0
msg_freec  db ' Clusters livres: ',0
msg_fail   db 'Erro ao ler FAT',13,10,0
