; ==================================================================
;                        FUNÇÃO EXECUTE_MV
; Renomeia um arquivo (mv origem destino) no root dir FAT12
; ==================================================================

execute_mv:
    ; Salva registradores
    push ax 
	push bx 
	push cx 
	push dx 
	push si 
	push di 
	push bp 
	push ds 
	push es

    ; Parsing de argumentos: AX=ptr origem ASCII, BX=ptr destino ASCII
    mov si, bp
    cmp byte [si], 0
    je execute_mv_no_filename

    call string_parse
    mov [mv_src], ax
    mov [mv_dst], bx
    cmp bx, 0
    je execute_mv_no_filename

    ; --------------------------------------------------------------
    ; Converte DESTINO para FAT 8.3 e copia para buffer próprio (11 bytes)
    ; --------------------------------------------------------------
    mov ax, [mv_dst]
    call string_uppercase
    call int_filename_convert          ; AX = ptr nome 8.3 (buffer temporário)
    jc execute_mv_write_fail

    ; Copia 11 bytes para mv_dst_fat_buf (fixa o conteúdo)
    mov si, ax
    mov di, mv_dst_fat_buf
    mov cx, 11
.copy_dst_83:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop .copy_dst_83

    ; Verifica se DESTINO já existe (usa o buffer próprio)
    ; file_exists deve aceitar ptr 8.3
    mov ax, mv_dst_fat_buf
    call file_exists
    jnc execute_mv_already_exists

    ; --------------------------------------------------------------
    ; Converte ORIGEM para FAT 8.3 e copia para buffer próprio (11 bytes)
    ; --------------------------------------------------------------
    mov ax, [mv_src]
    call string_uppercase
    call int_filename_convert
    jc execute_mv_notfound

    mov si, ax
    mov di, mv_src_fat_buf
    mov cx, 11
.copy_src_83:
    mov al, [si]
    mov [di], al
    inc si
    inc di
    loop .copy_src_83

    ; --------------------------------------------------------------
    ; Lê root dir e alinha segmentos
    ; --------------------------------------------------------------
    call disk_read_root_dir            ; carrega em ES:disk_buffer
    mov ax, es
    mov ds, ax                         ; DS=ES ⇒ DS:disk_buffer == ES:disk_buffer

    ; --------------------------------------------------------------
    ; Procura entrada da ORIGEM (usa DS:DI como base do buffer)
    ; --------------------------------------------------------------
    mov di, disk_buffer
    mov ax, mv_src_fat_buf             ; ponteiro para 11 bytes 8.3
    call disk_get_root_entry           ; DI → entrada dentro do disk_buffer
    jc execute_mv_notfound

    ; --------------------------------------------------------------
    ; Sobrescreve os 11 bytes do nome na entrada (ES:DI por segurança)
    ; --------------------------------------------------------------
    push di                            ; salva DI (opcional)
    mov si, mv_dst_fat_buf
    mov cx, 11
.rename_copy_loop:
    mov al, [si]
    mov es:[di], al                    ; escreve no segmento do disk_buffer
    inc si
    inc di
    loop .rename_copy_loop
    pop di

    ; --------------------------------------------------------------
    ; Grava root dir atualizado no disco
    ; --------------------------------------------------------------
    call disk_write_root_dir
    jc execute_mv_write_fail

    ; Sucesso
    mov si, mv_success_msg
    call print_string
    jmp execute_mv_exit

; ------------------------ Tratamento de erros ---------------------
execute_mv_no_filename:
    mov si, mv_nofilename_msg
    call print_string
    jmp execute_mv_exit

execute_mv_already_exists:
    mov si, mv_exists_msg
    call print_string
    jmp execute_mv_exit

execute_mv_notfound:
    mov si, mv_notfound_msg
    call print_string
    jmp execute_mv_exit

execute_mv_write_fail:
    mov si, mv_writefail_msg
    call print_string

; ------------------------------ Saída -----------------------------
execute_mv_exit:
    pop es 
	pop ds 
	pop bp 
	pop di 
	pop si 
	pop dx 
	pop cx 
	pop bx 
	pop ax
    ret


; -------------------------- Dados auxiliares MV ----------------------
mv_src              dw 0
mv_dst              dw 0

; Buffers fixos para nomes 8.3 (11 bytes cada)
mv_src_fat_buf      db 11 dup (0)
mv_dst_fat_buf      db 11 dup (0)

mv_success_msg      db 'Arquivo renomeado com sucesso', 13, 10, 0
mv_nofilename_msg   db 'Uso: mv <origem> <destino>', 13, 10, 0
mv_exists_msg       db 'O arquivo de destino ja existe', 13, 10, 0
mv_notfound_msg     db 'Arquivo de origem não encontrado', 13, 10, 0
mv_writefail_msg    db 'Erro ao renomear o arquivo', 13, 10, 0