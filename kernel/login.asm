; ==================================================================
; src/kernel/login.asm - Tela de Login Estilizada com Animação
; ==================================================================

; --- DADOS DE LOGIN ---
MAX_LOGIN_LEN       EQU 8                 ; Define o tamanho máximo do login (8 caracteres).
LOGIN_BUFFER        RESB MAX_LOGIN_LEN    ; Reserva um buffer de 8 bytes para armazenar o login digitado.
LOGIN_MODE          RESB 1                ; Reserva 1 byte para armazenar o modo de login (ex: usuário/senha).

CORRECT_PASSWORD_HASH DB 0x4F             ; Hash correto da senha "FEPOS".
                                          ; Em vez de armazenar a senha em texto puro,
                                          ; é guardado um valor hash para maior segurança.

; --- MENSAGENS DE INTERFACE ---
LOGIN_HEADER        db CHAR_ULCORNER, 20 dup (CHAR_HLINE), CHAR_URCORNER, 0x0D, 0x0A, 0
                                          ; Linha superior da caixa de login:
                                          ; CHAR_ULCORNER = canto superior esquerdo
                                          ; 20 vezes CHAR_HLINE = linha horizontal
                                          ; CHAR_URCORNER = canto superior direito
                                          ; 0x0D,0x0A = CR+LF (quebra de linha)
                                          ; 0 = terminador de string

LOGIN_TITLE         db CHAR_VLINE, "    FEP OS LOGIN    ", CHAR_VLINE, 0x0D, 0x0A, 0
                                          ; Linha do título centralizado dentro da caixa.
                                          ; CHAR_VLINE = borda vertical esquerda/direita.
                                          ; Texto: "FEP OS LOGIN".
                                          ; CR+LF no final e terminador 0.

LOGIN_FOOTER        db CHAR_LLCORNER, 20 dup (CHAR_HLINE), CHAR_LRCORNER, 0x0D, 0x0A, 0
                                          ; Linha inferior da caixa de login:
                                          ; CHAR_LLCORNER = canto inferior esquerdo
                                          ; 20 vezes CHAR_HLINE = linha horizontal
                                          ; CHAR_LRCORNER = canto inferior direito
                                          ; CR+LF e terminador 0.

LOGIN_PROMPT_USER   DB 0DH,0AH,"Username: ",0
                                          ; Mensagem de prompt para o nome de usuário.
                                          ; Começa com CR+LF para pular linha.
                                          ; Terminador 0 no final.

LOGIN_PROMPT_PASS   DB 0DH,0AH,"Password: ",0
                                          ; Mensagem de prompt para a senha.
                                          ; Também inicia em nova linha.
                                          ; Terminador 0 no final.

LOGIN_MSG_FAIL      DB 0DH,0AH,0DH,0AH,"!!! Acesso negado. Sistema bloqueado !!!",0DH,0AH,0
                                          ; Mensagem exibida quando a senha está incorreta.
                                          ; Inclui quebras de linha antes e depois para destaque.
                                          ; Terminador 0 no final.

; ------------------------------------------------------------------
; kernel_xor_hash - Calcula hash XOR (case-insensitive)
; Entrada: SI = ponteiro para string terminada em 0
; Saída:   AL = hash resultante
; ------------------------------------------------------------------
kernel_xor_hash:
    push cx                    ; Salva CX na pilha (será usado como registrador temporário).
    push si                    ; Salva SI na pilha (vamos percorrer a string).

    xor al, al                 ; Zera AL → acumulador do hash.
                               ; O hash será construído aplicando XOR sucessivo
                               ; de cada caractere da string.

.hash_loop:
    mov cl, [si]               ; Carrega o byte apontado por SI em CL.
    cmp cl, 0                  ; Verifica se chegou ao terminador nulo (0).
    je .hash_done              ; Se sim, fim da string → sai do loop.

    and cl, 0DFh               ; Normaliza para maiúscula:
                               ; 0x20 é o bit de diferença entre minúscula/maiúscula em ASCII.
                               ; AND com 0xDF (11011111b) força esse bit a 0,
                               ; convertendo letras minúsculas em maiúsculas.

    xor al, cl                 ; Faz XOR do acumulador (AL) com o caractere atual.
                               ; Isso vai "misturando" todos os bytes da string
                               ; em um único valor de hash.

    inc si                     ; Avança o ponteiro SI para o próximo caractere.
    jmp .hash_loop              ; Repete o processo até encontrar o terminador.

.hash_done:
    pop si                     ; Restaura o valor original de SI.
    pop cx                     ; Restaura o valor original de CX.
    ret                        ; Retorna com o hash final em AL.

; ------------------------------------------------------------------
; kernel_read_input - Lê string com limite e eco/sem eco
; Entrada: DI = buffer destino
;          CX = tamanho máximo permitido
;          LOGIN_MODE = 0 (eco normal), 1 (eco com '*')
; Saída:   String terminada em 0 no buffer
; ------------------------------------------------------------------
kernel_read_input:
    push ax                   ; Salva registradores usados
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov bp, di                ; Guarda o início do buffer em BP
                              ; (usado para saber até onde pode voltar no backspace)

.read_loop:
    mov ah, 0                 ; Função 0 do INT 16h → lê tecla pressionada
    int 16h                   ; AL = caractere ASCII, AH = scancode

    cmp al, 0Dh               ; Enter (0x0D)?
    je .done                  ; Se sim, finaliza leitura

    cmp al, 08h               ; Backspace (0x08)?
    je .handle_bs             ; Se sim, trata backspace

    cmp cx, 0                 ; Ainda há espaço no buffer?
    je .read_loop             ; Se não, ignora caractere e continua lendo

    mov dh, al                ; Salva caractere original em DH

    ; Decide se ecoa o caractere ou mostra '*'
    cmp byte [LOGIN_MODE], 1  ; LOGIN_MODE = 1 → modo senha
    jne .echo_normal
    mov al, '*'               ; Se for senha, imprime '*' em vez do caractere real
    jmp .print_and_store

.echo_normal:
    mov al, dh                ; Caso contrário, ecoa o caractere original

.print_and_store:
    mov bl, 0Ah                ; Define cor (atributo de vídeo)
    call print_char_color      ; Imprime caractere (AL) na tela

    mov al, dh                 ; Recupera caractere original
    mov [di], al               ; Armazena no buffer
    inc di                     ; Avança ponteiro do buffer
    dec cx                     ; Decrementa espaço restante
    jmp .read_loop             ; Continua lendo

; --------------------------------------------------------------
; Tratamento do Backspace
; --------------------------------------------------------------
.handle_bs:
    cmp di, bp                 ; Compara DI (posição atual no buffer) com BP (início do buffer).
                               ; Se forem iguais, significa que o buffer está vazio.
    je .read_loop              ; Se buffer vazio, não há nada para apagar → volta a ler.

    dec di                     ; Retrocede o ponteiro do buffer (aponta para o último caractere).
    mov byte [di], 0           ; Apaga o último caractere armazenando 0 (terminador nulo).
    inc cx                     ; Incrementa CX → libera espaço no contador de caracteres restantes.

    ; ----------------------------------------------------------
    ; Atualização visual no terminal
    ; ----------------------------------------------------------
    call cursor_left           ; Move o cursor uma posição para trás (função auxiliar).
    mov al, ' '                ; Prepara um espaço em branco para sobrescrever o caractere apagado.
    mov bl, 0Ah                ; Define atributo de cor (0Ah = verde claro em fundo preto).
    call print_char_color       ; Imprime o espaço na tela.

                               ; Agora o cursor está 1 posição à frente do que deveria.
    mov ah, 03h                ; INT 10h, função 03h → lê posição atual do cursor.
    xor bh, bh                 ; BH = número da página de vídeo (0).
    int 10h                    ; Retorna em DH (linha) e DL (coluna).

    dec dl                     ; Retrocede DL (coluna) em 1 → cursor volta para posição correta.
    mov ah, 02h                ; INT 10h, função 02h → posiciona cursor.
    xor bh, bh                 ; Página de vídeo = 0.
    int 10h                    ; Atualiza posição do cursor na tela.

    jmp .read_loop             ; Volta ao loop principal de leitura de entrada.

; --------------------------------------------------------------
; Finalização da leitura
; --------------------------------------------------------------
.done:
    mov byte [di], 0           ; Coloca terminador nulo (0) no final da string.
                               ; Isso garante que o buffer seja tratado como
                               ; uma string C-style (terminada em 0).

    ; ----------------------------------------------------------
    ; Restauração do contexto
    ; ----------------------------------------------------------
    pop bp                     ; Recupera o valor original de BP (base pointer).
    pop di                     ; Recupera o ponteiro de destino (DI).
    pop si                     ; Recupera o ponteiro de origem (SI).
    pop dx                     ; Recupera DX.
    pop cx                     ; Recupera CX (contador original).
    pop bx                     ; Recupera BX.
    pop ax                     ; Recupera AX.

    ret                        ; Retorna ao chamador.
                               ; Neste ponto, o buffer em [BP] contém a string
                               ; digitada pelo usuário, terminada em 0.
; ------------------------------------------------------------------
; kernel_login_check - Rotina principal de login
; ------------------------------------------------------------------
kernel_login_check:
    ; --------------------------------------------------------------
    ; Prólogo: salva todos os registradores que serão usados
    ; --------------------------------------------------------------
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    ; --------------------------------------------------------------
    ; 1. LIMPAR TELA E SETAR MODO DE TEXTO
    ; --------------------------------------------------------------
    mov ax, 0x0003             ; Modo de vídeo 03h = texto 80x25, 16 cores
    int 0x10                   ; BIOS vídeo → limpa tela e reseta cursor
    
    call cursor_home            ; Move cursor para canto superior esquerdo

    ; --------------------------------------------------------------
    ; 2. DESENHAR CABEÇALHO DA TELA DE LOGIN
    ; --------------------------------------------------------------
    mov bl, 0Ah                 ; Cor: verde claro sobre preto (atributo 0Ah)
    mov si, LOGIN_HEADER
    call print_string_color     ; Imprime linha superior da caixa
    mov si, LOGIN_TITLE
    call print_string_color     ; Imprime título "FEP OS LOGIN"
    mov si, LOGIN_FOOTER
    call print_string_color     ; Imprime linha inferior da caixa

    ; --------------------------------------------------------------
    ; 3. ENTRADA DO USERNAME
    ; --------------------------------------------------------------
    mov si, LOGIN_PROMPT_USER
    call print_string_color     ; Mostra "Username: "
    mov byte [LOGIN_MODE], 0    ; LOGIN_MODE = 0 → eco normal
    mov di, LOGIN_BUFFER        ; Ponteiro para buffer de entrada
    mov cx, MAX_LOGIN_LEN       ; Tamanho máximo permitido
    mov ah, 0x00                ; AH = 0 → eco normal
    call kernel_read_input      ; Lê string do usuário

    ; --------------------------------------------------------------
    ; 4. ENTRADA DA SENHA
    ; --------------------------------------------------------------
    mov si, LOGIN_PROMPT_PASS
    call print_string_color     ; Mostra "Password: "
    mov byte [LOGIN_MODE], 1    ; LOGIN_MODE = 1 → eco com '*'
    mov di, LOGIN_BUFFER        ; Reutiliza o mesmo buffer
    mov cx, MAX_LOGIN_LEN
    mov ah, 0x01                ; AH = 1 → modo senha
    call kernel_read_input      ; Lê senha do usuário

    ; --------------------------------------------------------------
    ; 5. VERIFICAÇÃO DO HASH DA SENHA
    ; --------------------------------------------------------------
    mov si, LOGIN_BUFFER        ; SI aponta para senha digitada
    call kernel_xor_hash        ; Calcula hash XOR case-insensitive
    cmp al, [CORRECT_PASSWORD_HASH] ; Compara com hash correto
    jne .login_failed_lock      ; Se diferente → falha
    jmp .login_exit_success     ; Se igual → sucesso

; --------------------------------------------------------------
; CASO DE FALHA NO LOGIN
; --------------------------------------------------------------
.login_failed_lock:
    push bx                     ; Salva BX, pois BL será alterado
    mov bl, 0Ch                 ; Cor: vermelho brilhante (atributo 0Ch)
    
    mov si, LOGIN_MSG_FAIL
    call print_string_color     ; Mostra mensagem "Acesso negado"

    pop bx                      ; Restaura BX
    cli                         ; Desabilita interrupções
    hlt                         ; Para CPU (sistema bloqueado)
    jmp .login_failed_lock      ; Loop infinito de bloqueio

; --------------------------------------------------------------
; CASO DE SUCESSO NO LOGIN
; --------------------------------------------------------------
.login_exit_success:
    ; Epílogo: restaura registradores na ordem inversa
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret                         ; Retorna ao chamador (kernel continua)