execute_ls:
    pusha

    ; Decide se lê root ou subdiretório atual
    mov ax, [current_dir_cluster]
    cmp ax, 0
    je .read_root

    ; Subdiretório atual
    call disk_load_cluster
    jc .fail
    mov cx, 16                  ; subdiretórios têm até 16 entradas
    jmp .setup

.read_root:
    call disk_read_root_dir
    jc .fail
    mov cx, ROOT_ENTRIES        ; root dir tem 224 entradas

.setup:
    mov ax, es
    mov ds, ax
    mov di, disk_buffer

.ls_loop:
    mov al, [di]
    cmp al, 0
    je .done
    cmp al, 0xE5
    je .next

    mov al, [di+11]
    test al, 0x08
    jnz .next                  ; pula volume label

    ; imprime nome (8.3, maiúsculas)
    push di
	mov al, [di+11]
	test al, 0x10
	setnz al              ; AL = 1 se for diretório, 0 se for arquivo
	call print_filename_upper
	pop di

    ; espaço separador
    mov al, ' '
    call print_char

    ; diretório ou arquivo?
    mov al, [di+11]
    test al, 0x10
    jz .is_file

    ; diretório
    mov si, dir_tag
    call print_string
    call print_newline
    jmp .next

.is_file:
    ; tamanho em bytes (DWORD em DX:AX)
    mov ax, [di+28]
    mov dx, [di+30]
    call print_dword_dec
    call print_newline

.next:
    add di, 32
    loop .ls_loop

.done:
    call print_newline
    popa
    ret

.fail:
    popa
    stc
    ret
	
	
print_filename_upper:
    pusha
    mov bp, di                  ; BP → entrada FAT12
    mov si, bp

    ; Verifica se é diretório
    mov al, [bp+11]
    test al, 0x10
    jnz .is_directory

    ; --- Nome (8 caracteres) ---
    mov cx, 8
.name_loop:
    mov al, [bp]
    cmp al, ' '
    je .name_skip
    cmp al, 'a'
    jb .name_print
    cmp al, 'z'
    ja .name_print
    sub al, 32
.name_print:
    call print_char
.name_skip:
    inc bp
    loop .name_loop

    ; --- Verifica se há extensão ---
    mov cx, 3
    mov bx, 0
    mov si, bp
.check_ext:
    mov al, [si]
    cmp al, ' '
    je .ext_space
    inc bx
.ext_space:
    inc si
    loop .check_ext

    cmp bx, 0
    je .done

    ; --- Imprime ponto ---
    mov al, '.'
    call print_char

    ; --- Imprime extensão (3 caracteres) ---
    mov cx, 3
.ext_loop:
    mov al, [bp]
    cmp al, ' '
    je .ext_skip
    cmp al, 'a'
    jb .ext_print
    cmp al, 'z'
    ja .ext_print
    sub al, 32
.ext_print:
    call print_char
.ext_skip:
    inc bp
    loop .ext_loop
    jmp .done

.is_directory:
    ; --- Nome (8 caracteres) apenas ---
    mov cx, 8
.dir_loop:
    mov al, [bp]
    cmp al, ' '
    je .dir_skip
    cmp al, 'a'
    jb .dir_print
    cmp al, 'z'
    ja .dir_print
    sub al, 32
.dir_print:
    call print_char
.dir_skip:
    inc bp
    loop .dir_loop

.done:
    popa
    ret