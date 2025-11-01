; --------------------------------------------------------------
; execute_cls
; --------------------------------------------------------------
; Objetivo:
;   Executar o comando "cls" ou "clear".
;   Limpa a tela de texto e reposiciona o cursor no canto superior esquerdo.
; Fluxo:
;   - Chama a rotina clear_screen (em video.asm).
;   - Retorna ao shell_loop para aguardar novo comando.
; --------------------------------------------------------------
execute_cls:
    call clear_screen               ; Limpa a tela (scroll up + cursor em 0,0)
    ret                 ; Volta ao loop principal do shell

