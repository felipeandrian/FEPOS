; ============================================================
; pwd -- mostra o diretório atual
; ============================================================

execute_pwd:
    pusha
    mov si, current_path
    call print_string
    call print_newline
    popa
    ret


