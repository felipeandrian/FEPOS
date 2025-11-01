; --------------------------------------------------------------------------
; execute_mem -- Mostra memória convencional e estendida (KB e MB)
; --------------------------------------------------------------------------
; Objetivo:
;   Exibir a quantidade de memória convencional (até 640 KB)
;   e a memória estendida detectada pela BIOS (em KB e MB).
; Estratégia:
;   - Usa INT 12h para obter memória convencional.
;   - Usa INT 15h, função 88h, para obter memória estendida.
;   - Converte valores numéricos para ASCII e imprime.
;   - Se não houver memória estendida, mostra mensagem apropriada.
; --------------------------------------------------------------------------

execute_mem:
    ; --- Memória convencional ---
    int 0x12                  ; BIOS: retorna em AX a quantidade de KB de RAM convencional
    mov bx, ax               ; BX = valor em KB
    call word_to_ascii        ; Converte número para string ASCII
    mov si, string_buff_word
    call print_string         ; Imprime valor numérico
    mov si, msg_memconv       ; Mensagem " KB de memória convencional"
    call print_string
    call print_newline

    ; --- Memória estendida ---
    mov ah, 0x88
    int 0x15                  ; BIOS: retorna em AX a quantidade de KB de RAM estendida
    jc .no_ext                ; Se Carry=1, função não suportada → sem memória estendida
    cmp ax, 0
    je .no_ext                ; Se valor = 0, também não há memória estendida

    ; Imprime em KB
    mov bx, ax
    call word_to_ascii
    mov si, string_buff_word
    call print_string
    mov si, msg_memext_kb     ; Mensagem " KB de memória estendida"
    call print_string

    ; Agora converte para MB (AX / 1024)
    mov bx, ax
    mov ax, bx
    mov cx, 1024
    xor dx, dx
    div cx                    ; AX = MB
    mov bx, ax
    call word_to_ascii
    mov si, string_buff_word
    call print_string
    mov si, msg_memext_mb     ; Mensagem " MB"
    call print_string

    call print_newline
    ret           ; Volta ao loop principal

.no_ext:
    mov si, msg_memnoext      ; Mensagem "Sem memória estendida"
    call print_string
    call print_newline
    ret


; --------------------------------------------------------------
; Mensagens de memória
; --------------------------------------------------------------
msg_memconv:    db ' KB de memoria convencional detectada', 0
msg_memext_kb:  db ' KB (', 0
msg_memext_mb:  db ' MB) de memoria estendida detectada', 0
msg_memnoext:   db 'Nenhuma memoria estendida detectada', 0

