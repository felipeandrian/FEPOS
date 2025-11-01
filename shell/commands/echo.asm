; --------------------------------------------------------------
; execute_echo
; --------------------------------------------------------------
; Objetivo:
;   Executar o comando "echo".
;   Imprime na tela o texto digitado após a palavra "echo".
; Fluxo:
;   - BP foi configurado em process_command para apontar para
;     o argumento do comando (texto após "echo").
;   - Exibe o texto.
;   - Em seguida, imprime uma nova linha.
;   - Retorna ao shell_loop.
; --------------------------------------------------------------
execute_echo:
    mov si, bp                      ; SI = ponteiro para argumento do comando
    call print_string               ; Exibe o texto digitado
    mov si, msg_newline             ; SI = string de nova linha (CR+LF)
    call print_string               ; Exibe quebra de linha
    ret                 ; Volta ao loop principal
