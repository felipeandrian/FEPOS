
execute_cat:
    ; --------------------------------------------------------------
    ; Salva todos os registradores que serão usados
    ; (feito manualmente em vez de PUSHA, para incluir DS/ES)
    ; --------------------------------------------------------------
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds                 ; Salva DS original
    push es                 ; Salva ES original

    ; --------------------------------------------------------------
    ; Verifica se foi fornecido um nome de arquivo
    ; BP aponta para os argumentos (nome do arquivo)
    ; --------------------------------------------------------------
    mov si, bp
    cmp byte [si], 0
    je execute_cat_no_filename ; Se vazio, mostra mensagem de erro

    mov ax, bp              ; AX = ponteiro para nome do arquivo

    ; --------------------------------------------------------------
    ; Verifica se o arquivo existe
    ; file_exists deve preservar registradores via pusha/popa
    ; Se não existir, Carry=1 → vai para "not found"
    ; --------------------------------------------------------------
    call file_exists
    jc execute_cat_not_found

    ; --------------------------------------------------------------
    ; Carrega o arquivo para memória
    ; CX = endereço linear de carregamento (0x8000)
    ; load_file carrega em ES:BX e retorna:
    ;   BX = tamanho real do arquivo
    ;   CF = erro
    ; --------------------------------------------------------------
    mov ax, bp
    mov cx, 0x8000
    call load_file
    jc execute_cat_load_error

    ; --------------------------------------------------------------
    ; Se tamanho = 0, apenas imprime newline e sai
    ; --------------------------------------------------------------
    cmp bx, 0
    je execute_cat_done_print_newline

    ; --------------------------------------------------------------
    ; Prepara ponteiro para leitura do arquivo
    ; Arquivo foi carregado em 0x8000 linear → ES:SI = 0800:0000
    ; BX = contador de bytes (tamanho real do arquivo)
    ; --------------------------------------------------------------
    mov ax, 0x0800
    mov es, ax
    mov si, 0x0000

execute_cat_loop:
    ; --------------------------------------------------------------
    ; Lê próximo byte do arquivo
    ; --------------------------------------------------------------
    mov al, [es:si]
    inc si

    ; --------------------------------------------------------------
    ; Substitui TAB (0x09) por espaço
    ; --------------------------------------------------------------
    cmp al, 0x09
    jne execute_cat_not_tab
    mov al, ' '
    jmp execute_cat_print_char_final

execute_cat_not_tab:
    ; --------------------------------------------------------------
    ; Trata LF (0x0A): antes imprime CR (0x0D)
    ; Isso garante formatação correta no console
    ; --------------------------------------------------------------
    cmp al, 0x0A
    jne execute_cat_print_char_final

    push ax
    mov al, 0x0D
    call print_char
    pop ax
    ; Cai para imprimir o LF normalmente

execute_cat_print_char_final:
    call print_char        ; Imprime caractere atual (AL)

    dec bx                 ; Decrementa contador de bytes restantes
    cmp bx, 0
    jne execute_cat_loop   ; Continua até acabar

    ; --------------------------------------------------------------
    ; Fim do loop de impressão
    ; --------------------------------------------------------------
    jmp execute_cat_done_print_newline

execute_cat_done_print_newline:
    pusha
    call print_newline     ; Garante quebra de linha no final
    popa
    jmp execute_cat_exit

; --------------------------------------------------------------
; Tratamento de erros
; --------------------------------------------------------------
execute_cat_no_filename:
    mov si, cat_nofilename_msg
    call print_string
    jmp execute_cat_exit

execute_cat_not_found:
    mov si, cat_notfound_msg
    call print_string
    jmp execute_cat_exit

execute_cat_load_error:
    mov si, read_failure
    call print_string

; --------------------------------------------------------------
; Saída da função: restaura registradores e volta ao shell
; --------------------------------------------------------------
execute_cat_exit:
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

