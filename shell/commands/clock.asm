; --------------------------------------------------------------------------
; execute_time -- Mostra a hora atual
; --------------------------------------------------------------------------
; Objetivo:
;   Exibir a hora atual no formato HH:MM:SS
; Estratégia:
;   - Usa a interrupção 1Ah, função 02h, que retorna a hora do RTC (em BCD).
;   - Converte cada campo (hora, minuto, segundo) de BCD para ASCII.
;   - Imprime no formato "HH:MM:SS".
;   - Retorna ao loop principal do shell.
; --------------------------------------------------------------------------

execute_time:
    mov ah, 02h
    int 1Ah              ; BIOS: Get Real-Time Clock Time
                         ; CH = hora (BCD)
                         ; CL = minutos (BCD)
                         ; DH = segundos (BCD)

    ; --- Hora ---
    mov al, ch           ; AL = hora em BCD
    call bcd_to_ascii    ; Converte para string ASCII em string_buff
    mov si, string_buff
    call print_string    ; Imprime "HH"
    mov al, ':'          ; Imprime separador
    call print_char

    ; --- Minutos ---
    mov al, cl           ; AL = minutos em BCD
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "MM"
    mov al, ':'
    call print_char

    ; --- Segundos ---
    mov al, dh           ; AL = segundos em BCD
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "SS"

    ; --- Finalização ---
    call print_newline   ; Pula linha
    ret       ; Volta ao loop principal
	
; --------------------------------------------------------------------------
; execute_date -- Mostra a data atual
; --------------------------------------------------------------------------
; Objetivo:
;   Exibir a data atual no formato DD/MM/AAAA
; Estratégia:
;   - Usa a interrupção 1Ah, função 04h, que retorna a data do RTC (em BCD).
;   - Converte cada campo (dia, mês, século, ano) de BCD para ASCII.
;   - Imprime no formato "DD/MM/AAAA".
;   - Retorna ao loop principal do shell.
; --------------------------------------------------------------------------

execute_date:
    mov ah, 04h
    int 1Ah              ; BIOS: Get Real-Time Clock Date
                         ; CH = século (BCD)
                         ; CL = ano (BCD)
                         ; DH = mês (BCD)
                         ; DL = dia (BCD)

    ; --- Dia ---
    mov al, dl           ; AL = dia em BCD
    call bcd_to_ascii    ; Converte para string ASCII em string_buff
    mov si, string_buff
    call print_string    ; Imprime "DD"
    mov al, '/'
    call print_char

    ; --- Mês ---
    mov al, dh           ; AL = mês em BCD
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "MM"
    mov al, '/'
    call print_char

    ; --- Século ---
    mov al, ch           ; AL = século em BCD (ex.: 20 para anos 2000)
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "20"

    ; --- Ano ---
    mov al, cl           ; AL = ano em BCD (ex.: 25 para 2025)
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "25"

    ; --- Finalização ---
    call print_newline   ; Pula linha
    ret      ; Volta ao loop principal
	
; --------------------------------------------------------------------------
; execute_datetime -- Mostra data e hora atuais chamando rotinas já prontas
; --------------------------------------------------------------------------
; Objetivo:
;   Exibir a data e a hora atuais no formato:
;       DD/MM/AAAA HH:MM:SS
; Estratégia:
;   - Usa a interrupção 1Ah, função 04h, para obter a data (em BCD).
;   - Converte e imprime dia, mês, século e ano.
;   - Imprime um espaço separador.
;   - Chama a rotina execute_time para imprimir a hora.
;   - Retorna ao loop principal do shell.
; --------------------------------------------------------------------------

execute_datetime:
    mov ah, 04h
    int 1Ah              ; BIOS: Get Real-Time Clock Date
                         ; CH = século (BCD)
                         ; CL = ano (BCD)
                         ; DH = mês (BCD)
                         ; DL = dia (BCD)

    ; --- Dia ---
    mov al, dl           ; AL = dia em BCD
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "DD"
    mov al, '/'
    call print_char

    ; --- Mês ---
    mov al, dh           ; AL = mês em BCD
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "MM"
    mov al, '/'
    call print_char

    ; --- Século ---
    mov al, ch           ; AL = século em BCD (ex.: 20h → "20")
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "20"

    ; --- Ano ---
    mov al, cl           ; AL = ano em BCD (ex.: 25h → "25")
    call bcd_to_ascii
    mov si, string_buff
    call print_string    ; Imprime "25"

    ; --- Espaço separador ---
    mov al, ' '
    call print_char

    ; --- Hora ---
    call execute_time    ; Reaproveita a rotina já pronta para imprimir "HH:MM:SS"

    ret ; Volta ao loop principal

