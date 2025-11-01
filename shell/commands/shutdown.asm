

; --------------------------------------------------------------
; execute_shutdown
; --------------------------------------------------------------
; Objetivo:
;   Executar o comando "exit" ou "shutdown".
;   Exibe mensagem de desligamento e para o sistema.
; Fluxo:
;   - Exibe mensagem "O sistema parou. Pode desligar o computador."
;   - Desabilita interrupções (CLI).
;   - Executa HLT (halt), que coloca a CPU em estado de espera.
;   - Entra em loop infinito (jmp $) para garantir que não retorne.
; --------------------------------------------------------------
execute_shutdown:
    mov si, msg_safe_to_shutdown    ; SI = ponteiro para mensagem de desligamento
    call print_string               ; Exibe mensagem final
    cli                             ; Desabilita interrupções de hardware
    hlt                             ; Para a CPU (aguarda desligamento físico)
    jmp $                           ; Loop infinito (não retorna nunca mais)

; --------------------------------------------------------------------------
; execute_shutdown_apm -- Executar desligamento via APM
; --------------------------------------------------------------------------
; Objetivo:
;   Chamar a rotina system_shutdown_apm para desligar o PC automaticamente
;   usando a BIOS APM (se suportado).
;   Se falhar, a própria rotina system_shutdown_apm já faz fallback
;   para a mensagem "Safe to shutdown".
; --------------------------------------------------------------------------
execute_shutdown_apm:
    call system_shutdown_apm        ; Tenta desligar via APM
    jmp $                           ; Se retornar, fica em loop infinito
	

; --------------------------------------------------------------------------
; system_shutdown_apm -- Desligar o PC via APM (Advanced Power Management)
; --------------------------------------------------------------------------
; Objetivo:
;   Usar a BIOS INT 15h (funções APM) para desligar o computador.
;
; Fluxo:
;   1. Conectar ao APM.
;   2. Ativar gerenciamento de energia.
;   3. Solicitar desligamento do sistema.
;   4. Se falhar, cai no fallback (mensagem + HLT).
; --------------------------------------------------------------------------
system_shutdown_apm:
    pusha

    ; --------------------------------------------------------------
    ; Etapa 1: Conectar ao APM
    ; --------------------------------------------------------------
    mov ax, 0x5301        ; APM Installation Check / Connect
    xor bx, bx           ; BX = 0 (BIOS)
    int 15h
    jc .apm_fail         ; Se CF=1, falhou

    ; --------------------------------------------------------------
    ; Etapa 2: Ativar gerenciamento de energia
    ; --------------------------------------------------------------
    mov ax, 0x5308        ; Enable/Disable Power Management
    mov bx, 0x0001        ; Device = All devices
    mov cx, 0x0001        ; Enable
    int 15h
    jc .apm_fail

    ; --------------------------------------------------------------
    ; Etapa 3: Solicitar desligamento
    ; --------------------------------------------------------------
    mov ax, 0x5307        ; Set Power State
    mov bx, 0x0001        ; Device = All devices
    mov cx, 0x0003        ; State = Off
    int 15h
    jc .apm_fail         ; Se falhar, vai para fallback

    ; Se chegou aqui, BIOS deve desligar imediatamente
    popa
    ret

; --------------------------------------------------------------
; Fallback: caso APM não esteja disponível ou falhe
; --------------------------------------------------------------
.apm_fail:
    popa
    mov si, msg_safe_to_shutdown
    call print_string
    cli
    hlt
    jmp $
