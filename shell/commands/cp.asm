
execute_cp:
    push ax 
	push bx 
	push cx 
	push dx 
	push si 
	push di 
	push bp 
	push ds 
	push es

    ; Parsing de argumentos
    mov si, bp
    cmp byte [si], 0
    je execute_cp_no_filename

    call string_parse             ; AX=origem ASCII, BX=destino ASCII
    mov [cp_src], ax
    mov [cp_dst], bx
    cmp bx, 0
    je execute_cp_no_filename

    ; --------------------------------------------------------------
    ; Carrega arquivo origem em buffer fixo (0x8000)
    ; --------------------------------------------------------------
    mov ax, [cp_src]              ; ASCII: load_file converte internamente
    mov cx, 0x8000
    call load_file
    jc execute_cp_notfound        ; não achou origem
    mov [cp_size], bx             ; tamanho (low word)

    ; --------------------------------------------------------------
    ; Grava arquivo destino
    ; write_file também espera ASCII e converte internamente
    ; --------------------------------------------------------------
    mov ax, [cp_dst]              ; ASCII
    mov bx, 0x8000                ; origem dos dados
    mov cx, [cp_size]             ; tamanho
    call write_file
    jc execute_cp_write_fail

    ; Sucesso
    mov si, cp_success_msg
    call print_string
    jmp execute_cp_exit

; ------------------------ Tratamento de erros ---------------------
execute_cp_no_filename:
    mov si, cp_nofilename_msg
    call print_string
    jmp execute_cp_exit

execute_cp_notfound:
    mov si, cp_notfound_msg
    call print_string
    jmp execute_cp_exit

execute_cp_write_fail:
    mov si, cp_writefail_msg
    call print_string

; ------------------------------ Saída -----------------------------
execute_cp_exit:
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
; Mensagens auxiliares para o comando "cp"
; --------------------------------------------------------------
; Objetivo:
;   Informar o usuário sobre o resultado da operação de cópia de arquivos.
;   Inclui mensagens de sucesso, erro e uso incorreto.
; --------------------------------------------------------------
cp_success_msg      db 'Arquivo copiado com sucesso', 13, 10, 0
cp_nofilename_msg   db 'Uso: cp <origem> <destino>', 13, 10, 0
cp_notfound_msg     db 'Arquivo de origem nao encontrado', 13, 10, 0
cp_writefail_msg    db 'Erro ao gravar o arquivo de destino', 13, 10, 0

cp_src              dw 0      ; Ponteiro para o nome do arquivo de origem
cp_dst              dw 0      ; Ponteiro para o nome do arquivo de destino
cp_size             dw 0      ; Tamanho do arquivo a ser copiado

