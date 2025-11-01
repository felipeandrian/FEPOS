; --------------------------------------------------------------------------
; execute_reboot -- Reinicia o sistema
; --------------------------------------------------------------------------
; Objetivo:
;   Reiniciar o computador a partir do shell.
; Estratégia:
;   - Exibe mensagem de reinício.
;   - Usa INT 19h (bootstrap loader da BIOS) para reinicializar.
;   - Se, por algum motivo, não reiniciar, entra em loop travado.
; --------------------------------------------------------------------------

execute_reboot:
    mov si, msg_reboot       ; Ponteiro para mensagem "Reiniciando..."
    call print_string        ; Exibe mensagem
    call print_newline       ; Pula linha

    ; --------------------------------------------------------------
    ; Opção 1: chamar bootstrap da BIOS
    ; INT 19h → rotina de bootstrap
    ;   - Reexecuta o carregador de boot (boot sector).
    ;   - Equivalente a um "soft reboot".
    ; --------------------------------------------------------------
    int 0x19

    ; --------------------------------------------------------------
    ; Caso a BIOS não reinicie (situação rara),
    ; desabilita interrupções e trava a CPU.
    ; --------------------------------------------------------------
.halt:
    cli                      ; Clear Interrupts → desabilita interrupções
    hlt                      ; Halt CPU → entra em estado de espera
    jmp .halt                ; Loop infinito para garantir travamento
	
