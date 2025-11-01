
execute_mkdir:
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

    ; Verifica se foi fornecido nome
    mov si, bp
    cmp byte [si], 0
    je execute_mkdir_no_name

    mov ax, bp              ; AX = ponteiro para nome
    call create_directory   ; Cria diretório
    jc execute_mkdir_fail   ; Se Carry=1 → erro

    ; Sucesso
    mov si, mkdir_success_msg
    call print_string
    jmp execute_mkdir_exit

execute_mkdir_no_name:
    mov si, mkdir_noname_msg
    call print_string
    jmp execute_mkdir_exit

execute_mkdir_fail:
    mov si, mkdir_fail_msg
    call print_string

execute_mkdir_exit:
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

; --- Mensagens ---
mkdir_success_msg:   db "Diretorio criado com sucesso.", 0
mkdir_fail_msg:      db "Erro ao criar diretorio.", 0
mkdir_noname_msg:    db "Uso: mkdir NOME", 0