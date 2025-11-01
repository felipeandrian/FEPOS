execute_rmdir:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    mov si, bp
    cmp byte [si], 0
    je rmdir_no_name

    mov ax, bp
    call remove_directory
    jc rmdir_fail

    mov si, rmdir_success_msg
    call print_string
    jmp rmdir_exit

rmdir_no_name:
    mov si, rmdir_noname_msg
    call print_string
    jmp rmdir_exit

rmdir_fail:
    mov si, rmdir_fail_msg
    call print_string

rmdir_exit:
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

rmdir_success_msg: db "Diretorio removido com sucesso.", 0
rmdir_fail_msg:    db "Erro ao remover diretorio.", 0
rmdir_noname_msg:  db "Uso: rmdir NOME", 0
