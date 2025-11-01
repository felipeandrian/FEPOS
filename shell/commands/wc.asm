
execute_wc:
    pusha
    push ds
    push es

    ; 1. Validar Argumento (Nome do Ficheiro)
    mov si, bp
    cmp byte [si], 0
    je .wc_no_filename

    ; 2. Carregar o Ficheiro
    mov ax, bp          ; AX = ponteiro para nome do arquivo
    mov cx, 0x8000      ; Endereço linear de carregamento
    call load_file
    jc .wc_file_not_found
    ; load_file RETORNA O TAMANHO (16-bit) EM BX

    ; 3. Preparar Contadores e Ponteiros
    mov [wc_lines_count], dword 0
    mov [wc_words_count], dword 0
    mov [wc_in_word_flag], byte 0
    ; A contagem de bytes é o próprio BX
    mov cx, bx          ; CX = Tamanho 16-bit (contador de loop)

    mov ax, 0x0800
    mov es, ax          ; ES = 0x0800 (segmento do buffer)
    mov si, 0x0000      ; SI = 0x0000 (offset do buffer)
    
    ; Se o ficheiro estiver vazio, salta a contagem
    cmp cx, 0
    je .wc_loop_done

.wc_loop:
    mov al, [es:si] ; Lê 1 byte do ficheiro na memória

    ; --- Lógica de Contagem de Linhas ---
    cmp al, 0x0A
    jne .not_newline
    inc dword [wc_lines_count]
.not_newline:

    ; --- Lógica de Contagem de Palavras ---
    cmp al, ' '
    je .is_whitespace
    cmp al, 0x09
    je .is_whitespace
    cmp al, 0x0A
    je .is_whitespace
    jmp .is_not_whitespace

.is_whitespace:
    mov [wc_in_word_flag], byte 0
    jmp .next_byte

.is_not_whitespace:
    cmp [wc_in_word_flag], byte 1
    je .next_byte
    mov [wc_in_word_flag], byte 1
    inc dword [wc_words_count]

.next_byte:
    inc si ; Avança ponteiro de leitura
    loop .wc_loop ; Decrementa CX e continua

.wc_loop_done:
    ; 5. Imprimir Resultados
    ; Imprime Linhas
    mov si, wc_msg_lines
    call print_string
    mov ax, [wc_lines_count]
    mov dx, [wc_lines_count+2]
    call print_dword_dec

    ; Imprime Palavras
    mov si, wc_msg_words
    call print_string
    mov ax, [wc_words_count]
    mov dx, [wc_words_count+2]
    call print_dword_dec
    
    ; Imprime Bytes (O valor 16-bit que estava em BX/CX)
    mov si, wc_msg_bytes
    call print_string
    mov ax, [load_file_file_size] ; (BX foi salvo aqui por load_file)
    mov dx, 0 ; Zeramos o high-word
    call print_dword_dec
    
    mov al, ' '
    call print_char
    mov si, bp
    call print_string
    
    call print_newline
    jmp .wc_exit

.wc_no_filename:
    mov si, wc_usage_msg
    call print_string
    jmp .wc_exit

.wc_file_not_found:
    mov si, cat_notfound_msg
    call print_string
    
.wc_exit:
    pop es
    pop ds
    popa
    ret

; --------------------------------------------------------------
; Mensagens auxiliares para o comando "wc"
; --------------------------------------------------------------
; Objetivo:
;   Exibir instruções e resultados do comando "wc"
;   que conta linhas, palavras e bytes em um arquivo.
; --------------------------------------------------------------
wc_usage_msg:   db 'Uso: wc <arq>', 13, 10, 0
wc_msg_lines:   db ' Linhas: ', 0
wc_msg_words:   db ' Palavras: ', 0
wc_msg_bytes:   db ' Bytes: ', 0

; --------------------------------------------------------------
; Variáveis globais usadas pelo wc
; --------------------------------------------------------------
; Objetivo:
;   Armazenar contadores usados pelo comando "wc".
;   Usa dwords (32 bits) para suportar arquivos grandes.
; --------------------------------------------------------------
wc_lines_count:  dd 0       ; Contador de linhas
wc_words_count:  dd 0       ; Contador de palavras
wc_bytes_count:  dd 0       ; Contador de bytes
wc_in_word_flag: db 0       ; Flag: 0 = fora de palavra, 1 = dentro