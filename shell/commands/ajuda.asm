; --------------------------------------------------------------
; execute_ajuda
; --------------------------------------------------------------
; Objetivo:
;   Executar o comando "ajuda".
;   Exibe a lista de comandos disponíveis e suas descrições.
; Fluxo:
;   - Carrega SI com ponteiro para msg_ajuda (string com ajuda).
;   - Chama print_string para exibir.
;   - Retorna ao shell_loop.
; --------------------------------------------------------------
execute_ajuda:
    mov si, msg_ajuda        ; SI = ponteiro para string de ajuda
    call print_string        ; Exibe lista de comandos na tela
    ret ; Volta ao loop principal do shell
