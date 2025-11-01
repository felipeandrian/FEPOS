; ==================================================================
;                        FUNÇÃO EXECUTE_RM
; Remove um arquivo do disquete (estilo comando rm)
; ==================================================================
execute_rm:
    ; --------------------------------------------------------------
    ; Salva todos os registradores que serão usados
    ; --------------------------------------------------------------
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    ; --------------------------------------------------------------
    ; Verifica se foi fornecido um nome de arquivo
    ; BP aponta para os argumentos (nome do arquivo)
    ; --------------------------------------------------------------
    mov si, bp
    cmp byte [si], 0
    je execute_rm_no_filename

    mov ax, bp              ; AX = ponteiro para nome do arquivo

    ; --------------------------------------------------------------
    ; Chama rotina de remoção
    ; remove_file deve:
    ;   - Retornar CF=0 em caso de sucesso
    ;   - Retornar CF=1 em caso de falha
    ; --------------------------------------------------------------
    call remove_file
    jc execute_rm_failure   ; Se Carry=1 → erro

    ; --------------------------------------------------------------
    ; Sucesso
    ; --------------------------------------------------------------
    mov si, rm_success_msg
    call print_string
    mov si, bp              ; Imprime o nome do arquivo removido
    call print_string
    call print_newline
    jmp execute_rm_exit

; --------------------------------------------------------------
; Tratamento de erros
; --------------------------------------------------------------
execute_rm_no_filename:
    mov si, rm_nofilename_msg
    call print_string
    jmp execute_rm_exit

execute_rm_failure:
    mov si, rm_failure_msg
    call print_string

; --------------------------------------------------------------
; Saída da função: restaura registradores e volta ao shell
; --------------------------------------------------------------
execute_rm_exit:
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
; Mensagens auxiliares para o comando "rm"
; --------------------------------------------------------------
; Objetivo:
;   Informar sucesso ou erro ao tentar remover um arquivo.
;   Também alerta quando nenhum nome de arquivo foi fornecido.
; --------------------------------------------------------------
rm_success_msg:    db 'Arquivo removido com sucesso: ', 0
rm_nofilename_msg: db 'Nenhum nome de arquivo fornecido', 13, 10, 0
rm_failure_msg:    db 'Erro ao remover o arquivo', 13, 10, 0
