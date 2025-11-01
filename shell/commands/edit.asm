; Bugado precisa arrumar Comando EDIT - Editor de texto simples com salvamento em disco FAT12

edit: pusha

    ; DEBUG: entrada na função
    mov si, edit_enter_msg
    call print_string
    call print_newline

    ; Inicializa ponteiros e contadores
    mov di, edit_buffer       ; ponteiro para buffer de texto
    mov cx, 0                 ; contador de caracteres no buffer

.edit_loop:
    call read_char            ; captura tecla (retorna em al)
    cmp al, 27                ; ESC para sair do editor
    je .exit_edit

    cmp al, 13                ; Enter (quebra linha)
    jne .not_enter

    ; Move cursor para início da próxima linha
    mov ah, 3                 ; função BIOS para ler cursor
    mov bh, 0                 ; página de vídeo 0
    int 0x10
    inc dh                    ; incrementa linha (DH = linha)
    mov dl, 0                 ; coluna 0 (DL = coluna)
    mov ah, 2                 ; função BIOS para posicionar cursor
    mov bh, 0                 ; página de vídeo 0
    int 0x10

    jmp .edit_loop

.not_enter:
    cmp al, 8                 ; Backspace
    jne .store_char

    ; Trata backspace
    cmp cx, 0
    je .edit_loop             ; nada para apagar
    dec di
    dec cx
    mov byte [di], 0
    ; Apaga caractere da tela (move cursor para trás e apaga)
    mov ah, 0x0E
    mov al, 8                 ; backspace
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .edit_loop

.store_char:
    ; Armazena caractere no buffer
    mov [di], al
    inc di
    inc cx

    ; Exibe caractere na tela
    mov ah, 0x0E              ; função BIOS teletipo para imprimir caractere
    mov bh, 0
    mov bl, 7                 ; cor cinza claro
    int 0x10

    jmp .edit_loop

.exit_edit:
    mov byte [di], 0          ; termina string no buffer de texto
    mov si, edit_exit_msg
    call print_string
    call print_newline

    mov si, edit_save_msg
    call print_string
    call print_newline

    mov bx, cx                ; salva tamanho do texto em BX

    mov di, edit_filename_buffer
    call read_string          ; lê nome do arquivo, retorna tamanho em CX

    mov si, edit_filename_buffer  ; ponteiro para nome do arquivo
    mov bx, edit_buffer           ; ponteiro para buffer de texto
    mov cx, bx                    ; incorreto, substitua por:
    mov cx, bx                    ; aqui deve ser o tamanho salvo antes (em BX)
    mov cx, bx                    ; para evitar confusão, use outro registrador para tamanho

    ; Correção correta:
    mov cx, bx                    ; mov cx, tamanho salvo antes (BX)

    call save_file_from_editor

    popa
    ret

; -------------------------------------------------------------------------
; Função para salvar arquivo a partir do editor
; Parâmetros:
;   SI - ponteiro para nome do arquivo (string terminada em zero)
;   BX - tamanho do arquivo (bytes)
;   DX - ponteiro para buffer de texto
; -------------------------------------------------------------------------
save_file_from_editor: 

	pusha

    mov ax, si                ; ponteiro para nome do arquivo
    mov bx, bx                ; ponteiro para buffer de texto
    mov cx, cx                ; tamanho do arquivo

    call write_file

    jc .save_fail

    mov si, save_success_msg
    call print_string
    call print_newline
    jmp .save_end

.save_fail:
    mov si, save_fail_msg
    call print_string
    call print_newline

.save_end:
    popa
    ret
; Buffer para texto editado (tamanho 512 bytes)
edit_buffer: times 512 db 0

; Buffer para nome do arquivo (tamanho 32 bytes)
edit_filename_buffer: times 32 db 0

; Mensagens de debug
edit_enter_msg: db 'Entrou no editor simples. Pressione ESC para sair.', 0
edit_exit_msg:  db 'Saindo do editor.', 0
edit_save_msg:  db 'Digite o nome do arquivo para salvar:', 0
save_success_msg: db 'Arquivo salvo com sucesso.', 0
save_fail_msg: db 'Falha ao salvar o arquivo.', 0


; Função read_string - lê string do teclado até ENTER (CR) ou ESC
; Entrada: DI = buffer para armazenar string
; Saída: CX = tamanho da string (sem terminador), buffer terminado em zero
read_string: 
	pusha

    mov cx, 0              ; contador de caracteres

.read_loop:
    call read_char         ; lê caractere em AL
    cmp al, 27             ; ESC para cancelar entrada
    je .end_input
    cmp al, 13             ; ENTER (CR) para finalizar
    je .end_input

    cmp al, 8              ; Backspace
    jne .store_char

    ; Trata backspace
    cmp cx, 0
    je .read_loop          ; nada para apagar
    dec di
    dec cx
    mov byte [di], 0
    ; Apaga caractere da tela
    mov ah, 0x0E
    mov al, 8             ; backspace
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .read_loop

.store_char:
    mov [di], al
    inc di
    inc cx
    ; Exibe caractere na tela
    mov ah, 0x0E
    mov bh, 0
    mov bl, 7
    int 0x10
    jmp .read_loop

.end_input:
    mov byte [di], 0      ; termina string com zero
    popa
    ret