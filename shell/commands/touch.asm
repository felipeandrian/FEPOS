
; ==================================================================
;                        FUNÇÃO EXECUTE_TOUCH
; Cria um arquivo vazio (estilo comando touch)
; ==================================================================
execute_touch:
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
    je execute_touch_no_filename

    mov ax, bp              ; AX = ponteiro para nome
    call create_file     ; Cria arquivo vazio
    jc execute_touch_fail   ; Se Carry=1 → erro

    ; Sucesso
    mov si, touch_success_msg
    call print_string
    jmp execute_touch_exit

execute_touch_no_filename:
    mov si, touch_nofilename_msg
    call print_string
    jmp execute_touch_exit

execute_touch_fail:
    mov si, touch_fail_msg
    call print_string

execute_touch_exit:
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


; --------------------------------------------------------------
; Mensagens auxiliares para o comando "touch"
; --------------------------------------------------------------
; Objetivo:
;   Informar o usuário sobre o resultado da criação de arquivos vazios.
; --------------------------------------------------------------
touch_success_msg    db 'Arquivo vazio criado com sucesso', 13, 10, 0
touch_nofilename_msg db 'Uso: touch <arq>', 13, 10, 0
touch_fail_msg       db 'Erro ao criar o arquivo', 13, 10, 0
