; --------------------------------------------------------------
; execute_ver
; --------------------------------------------------------------
; Objetivo:
;   Executar o comando "ver".
;   Exibe a versão do sistema operacional.
; Fluxo:
;   - Carrega SI com ponteiro para msg_ver (string com versão).
;   - Chama print_string para exibir.
;   - Retorna ao shell_loop.
; --------------------------------------------------------------
execute_ver:
    mov si, msg_ver          ; SI = ponteiro para string de versão
    call print_string        ; Exibe a versão
    ret           ; Volta ao loop principal
	
