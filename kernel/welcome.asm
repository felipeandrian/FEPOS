; ==================================================================
; src/kernel/welcome.asm - Tela de boas-vindas 
; ==================================================================

BITS 16                        ; Código em modo real 16 bits

; ---------------------------------------------------------------
; Tela de boas-vindas
; ---------------------------------------------------------------
welcome_show:
    pusha                       ; Salva todos os registradores gerais (AX, BX, CX, DX, SI, DI, BP, SP)
                                ; Isso garante que a rotina não altere o estado do chamador.

    ; -----------------------------------------------------------
    ; 1. LIMPAR TELA E SETAR MODO DE TEXTO
    ; -----------------------------------------------------------
    mov ax, 0x0003              ; Modo de vídeo 03h = texto 80x25, 16 cores
    int 0x10                    ; BIOS vídeo → limpa a tela e reseta cursor

    ; -----------------------------------------------------------
    ; 2. GARANTIR CURSOR NO TOPO (0,0)
    ; -----------------------------------------------------------
    mov ah, 0x02                ; Função 02h do INT 10h → posicionar cursor
    mov bh, 0x00                ; Página de vídeo = 0
    mov dx, 0x0000              ; DH = linha 0, DL = coluna 0
    int 0x10                    ; Cursor vai para canto superior esquerdo

    ; -----------------------------------------------------------
    ; --- INÍCIO DO DISPLAY ---
    ; Aqui começa a renderização da tela de boas-vindas
    ; -----------------------------------------------------------

    ; BARRA SUPERIOR DE BORDAS
    mov bl, 0Ah                 ; Cor: verde claro sobre preto (atributo 0Ah)
    mov si, banner_top_line     ; SI aponta para string da linha superior
    call print_string_color     ; Imprime a linha superior da moldura

    ; TÍTULO CENTRAL
    mov bl, 0Eh                 ; Cor: amarelo claro sobre preto (atributo 0Eh)
    mov si, banner_title        ; SI aponta para string do título
    call print_string_color     ; Imprime o título estilizado

    ; SEPARADOR
    mov bl, 0Ah                 ; Volta para verde claro
    mov si, banner_sep          ; SI aponta para string separadora
    call print_string_color     ; Imprime a linha de separação

 ; --------------------------------------------------------------
; Mensagens estilo "boot" com efeito de digitação
; --------------------------------------------------------------
    mov bl, 0Ah                 ; Cor: verde claro
    mov si, msg1                ; Ponteiro para a primeira mensagem
    call type_effect_color      ; Exibe com efeito de digitação

    mov bl, 0Ah                 ; Verde claro novamente
    mov si, msg2
    call type_effect_color

    mov bl, 0Ch                 ; Vermelho brilhante
    mov si, msg3
    call type_effect_color

    mov bl, 0Ah                 ; Volta para verde claro
    mov si, msg4
    call type_effect_color

; --------------------------------------------------------------
; Quebra de linha (CR + LF)
; --------------------------------------------------------------
    mov bl, 0Ah                 ; Cor verde claro
    mov al, 0x0D                ; Carriage Return (volta ao início da linha)
    call print_char_color
    mov al, 0x0A                ; Line Feed (avança para próxima linha)
    call print_char_color

; --------------------------------------------------------------
; Banner ASCII Art Hacker/FEPOS
; --------------------------------------------------------------
    mov bl, 0Ah                 ; Cor verde brilhante
    mov si, art1
    call print_string_color
    mov si, art2
    call print_string_color
    mov si, art3
    call print_string_color
    mov si, art4
    call print_string_color
    mov si, art5
    call print_string_color
    mov si, art6
    call print_string_color

; --------------------------------------------------------------
; Barra de progresso
; --------------------------------------------------------------
    mov bl, 0Eh                 ; Cor amarela
    mov si, progress            ; String da barra de progresso
    call print_string_color

; --------------------------------------------------------------
; Mensagem final de acesso
; --------------------------------------------------------------
    mov bl, 0Ah                 ; Verde claro
    mov si, access              ; Mensagem de "Acesso liberado" ou similar
    call print_string_color

; --------------------------------------------------------------
; Pausa: esperar tecla antes de voltar ao shell
; --------------------------------------------------------------
    mov ah, 0                   ; Função 0 do INT 16h → aguarda tecla
    int 16h

    popa                        ; Restaura todos os registradores salvos com PUSHA
    ret                         ; Retorna ao chamador (kernel continua execução)

; ---------------------------------------------------------------
; Dados (Com arte ASCII )
; ---------------------------------------------------------------

; Linha superior da moldura do banner
banner_top_line db CHAR_ULCORNER, 36 dup (CHAR_HLINE), CHAR_URCORNER, 0x0D, 0x0A, 0
                                ; CHAR_ULCORNER = canto superior esquerdo
                                ; 36 vezes CHAR_HLINE = linha horizontal
                                ; CHAR_URCORNER = canto superior direito
                                ; 0x0D,0x0A = CR+LF (quebra de linha)
                                ; 0 = terminador de string

; Linha do título centralizado
banner_title    db CHAR_VLINE, "     FEP OS 16-BIT BOOT SEQUENCE    ", CHAR_VLINE, 0x0D, 0x0A, 0
                                ; CHAR_VLINE = borda vertical esquerda/direita
                                ; Texto centralizado
                                ; CR+LF no final
                                ; 0 = terminador

; Linha inferior da moldura
banner_sep      db CHAR_LLCORNER, 36 dup (CHAR_HLINE), CHAR_LRCORNER, 0x0D, 0x0A, 0
                                ; CHAR_LLCORNER = canto inferior esquerdo
                                ; 36 vezes CHAR_HLINE
                                ; CHAR_LRCORNER = canto inferior direito
                                ; CR+LF e terminador

; ---------------------------------------------------------------
; Mensagens estilo "boot log"
; ---------------------------------------------------------------
msg1 db "[OK] Inicializando subsistema FAT12...",0x0D,0x0A,0
msg2 db "[OK] Carregando modulos criticos...",0x0D,0x0A,0
msg3 db "[FAIL] Integridade bypassed. (System Administrator Mode)",0x0D,0x0A,0
msg4 db "[OK] Console seguro ativo. HASH CHECK COMPLETE.",0x0D,0x0A,0
                                ; Cada mensagem termina com CR+LF e 0

; ---------------------------------------------------------------
; Arte ASCII com as letras F E P O S
; Cada linha é uma parte da arte, usando CHAR_BLOCK para blocos
; ---------------------------------------------------------------
art1 db 10 dup(SPACE), CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, 0x0D, 0x0A, 0
art2 db 10 dup(SPACE), CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, CHAR_BLOCK, SPACE, CHAR_BLOCK, SPACE, SPACE, CHAR_BLOCK, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, 0x0D, 0x0A, 0
art3 db 10 dup(SPACE), CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, SPACE, SPACE, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, 0x0D, 0x0A, 0
art4 db 10 dup(SPACE), CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, SPACE, 0x0D, 0x0A, 0
art5 db 10 dup(SPACE), CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, SPACE, SPACE, SPACE, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, CHAR_BLOCK, SPACE, 0x0D, 0x0A, 0
art6 db 0x0D, 0x0A, 0          ; Linha em branco (espaçador final)

; ---------------------------------------------------------------
; Barra de progresso e mensagem final
; ---------------------------------------------------------------
progress db "Inicializando FEP OS... [####################] 100%",0x0D,0x0A,0
                                ; Simula barra de progresso completa
                                ; CR+LF no final

access  db ">>> ACESSO AUTORIZADO - PRESSIONE UMA TECLA <<<",0x0D, 0x0A, 0
                                ; Mensagem final de acesso autorizado
                                ; CR+LF no final