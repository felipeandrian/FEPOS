; ==================================================================
; src/drivers/video.asm - Funções de Vídeo (BIOS)
; ==================================================================
; --------------------------------------------------------------
; print_string
; --------------------------------------------------------------
; Objetivo:
;   Exibir uma string terminada em zero (null-terminated) na tela.
;   Utiliza a função de teletipo da BIOS (INT 10h, função 0Eh).
;
; Contrato:
;   Entrada:
;     DS:SI → ponteiro para a string a ser exibida
;   Saída:
;     Nenhuma (todos os registradores são preservados)
;
; Observações:
;   - A função percorre a string byte a byte até encontrar o terminador nulo.
;   - Cada caractere é impresso usando a interrupção 10h da BIOS.
;   - Usa `lodsb` para carregar o próximo caractere e avançar o ponteiro.
; --------------------------------------------------------------

print_string:
    pusha                   ; Salva todos os registradores (AX, BX, CX, DX, SI, DI, BP, SP)

    mov ah, 0x0E            ; AH = 0Eh → função de teletipo da BIOS (imprime caractere em AL)

print_string_loop:
    lodsb                   ; AL ← [SI], SI++ (carrega próximo byte da string)
    cmp al, 0               ; Verifica se é o terminador nulo
    je print_string_done    ; Se for 0, encerra a impressão

    int 0x10                ; Chama BIOS para imprimir caractere em AL
    jmp print_string_loop   ; Continua com o próximo caractere

print_string_done:
    popa                    ; Restaura todos os registradores salvos
    ret                     ; Retorna ao chamador
; --------------------------------------------------------------
; print_char
; --------------------------------------------------------------
; Objetivo:
;   Exibir um único caractere contido em AL na tela.
;   Utiliza a função de teletipo da BIOS (INT 10h, função 0Eh).
;
; Contrato:
;   Entrada:
;     AL = caractere ASCII a ser exibido
;   Saída:
;     Nenhuma (todos os registradores são preservados)
;
; Observações:
;   - Ideal para imprimir caracteres isolados, como parte de uma rotina maior.
;   - Pode ser usada em conjunto com `print_string` para controle fino.
; --------------------------------------------------------------

print_char:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x0E        ; função teletipo BIOS
    mov bh, 0x00        ; página
    mov bl, 0x07        ; atributo (branco sobre preto)
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret


print_char_color:
    push ax
    push bx
    push cx
    push dx
    
    cmp al, 0x0D
    je .use_tty
    cmp al, 0x0A
    je .use_tty
    
    mov ah, 0x09
    mov cx, 1       
    int 0x10

    mov ah, 0x03
    xor bh, bh
    int 0x10
    inc dl
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    
    jmp .done_pc

.use_tty:
    mov ah, 0x0E 
    int 0x10
    
.done_pc:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; imprime string com cor (RÁPIDO)
print_string_color:
    push ax
    push si
    push bx
.psc_loop:
    lodsb
    cmp al, 0
    je .done
    call print_char_color
    jmp .psc_loop
.done:
    pop bx
    pop si
    pop ax
    ret
	
; --------------------------------------------------------------
; read_char
; --------------------------------------------------------------
; Objetivo:
;   Ler um caractere do teclado, aguardando até que o usuário pressione uma tecla.
;   Utiliza a interrupção da BIOS INT 16h, função 00h.
;
; Contrato:
;   Entrada:
;     Nenhuma
;   Saída:
;     AL = código ASCII da tecla pressionada
;     AH = scancode da tecla
;
; Observações:
;   - A função é bloqueante: espera até que uma tecla seja pressionada.
;   - Pode ser usada para controle interativo (ex: prompts, menus).
; --------------------------------------------------------------
read_char:
    mov ah, 0x00            ; AH = 00h → função de leitura de tecla da BIOS
    int 0x16                ; AL = ASCII, AH = scancode
    ret                     ; Retorna ao chamador

; --------------------------------------------------------------
; print_newline
; --------------------------------------------------------------
; Objetivo:
;   Mover o cursor para o início da próxima linha no terminal.
;   Implementado imprimindo os caracteres CR (Carriage Return) e LF (Line Feed).
;
; Contrato:
;   Entrada: Nenhuma
;   Saída: Nenhuma (todos os registradores são preservados)
;
; Observações:
;   - CR (0x0D) retorna o cursor ao início da linha atual.
;   - LF (0x0A) avança o cursor para a linha seguinte.
;   - Juntos, simulam uma quebra de linha.
; --------------------------------------------------------------
print_newline:
    pusha                   ; Salva todos os registradores

    mov ah, 0x0E             ; AH = 0X0E → função de teletipo da BIOS
    mov al, 0x0D              ; AL = CR (Carriage Return)
    int 0x10                 ; Imprime CR

    mov al, 0x0A              ; AL = LF (Line Feed)
    int 0x10                 ; Imprime LF

    popa                   ; Restaura registradores
    ret                    ; Retorna ao chamador

; --------------------------------------------------------------
; print_backspace
; --------------------------------------------------------------
; Objetivo:
;   Apagar o último caractere exibido na tela.
;   Simula o efeito de backspace sobrescrevendo com espaço.
;
; Contrato:
;   Entrada: Nenhuma
;   Saída: Nenhuma
;
; Observações:
;   - Envia um backspace (0x08) para mover o cursor para trás.
;   - Imprime um espaço para apagar o caractere anterior.
;   - Envia outro backspace para reposicionar o cursor.
; --------------------------------------------------------------
print_backspace:
    mov al, 0x08            ; AL = backspace
    call print_char         ; Move cursor para trás


    mov al, ' '             ; AL = espaço
    call print_char         ; Sobrescreve o caractere anterior

    mov al, 0x08            ; AL = backspace novamente
    call print_char         ; Reposiciona o cursor

    ret                     ; Retorna ao chamador

; --------------------------------------------------------------
; clear_screen
; --------------------------------------------------------------
; Objetivo:
;   Limpar toda a tela de texto e reposicionar o cursor no canto superior esquerdo.
;   Utiliza a interrupção da BIOS INT 10h com função 06h (scroll up).
;
; Contrato:
;   Entrada: Nenhuma
;   Saída: Tela limpa e cursor na posição (linha 0, coluna 0)
;   Preservação: Todos os registradores são preservados com pusha/popa.
;
; Observações:
;   - A função scroll up com AL = 0 limpa toda a área especificada.
;   - BH define o atributo de cor (0x07 = branco sobre preto).
;   - CX e DX definem a área da tela a ser limpa (de 0,0 até 24,79).
;   - Após a limpeza, a função 02h posiciona o cursor no topo.
; --------------------------------------------------------------
clear_screen:
    pusha                   ; Salva todos os registradores

    mov ah, 0x06            ; AH = 06h → função scroll up (limpar área)
    mov al, 0x00            ; AL = 0 → limpa todas as linhas da área
    mov bh, 0x07            ; BH = atributo de cor (branco sobre preto)
    mov cx, 0x0000          ; CX = coordenada inicial (linha 0, coluna 0)
    mov dx, 0x184F          ; DX = coordenada final (linha 24, coluna 79)
    int 0x10                ; Chama BIOS para executar limpeza

    mov ah, 0x02            ; AH = 02h → função posicionar cursor
    mov bh, 0x00            ; BH = página de vídeo 0
    mov dx, 0x0000          ; DX = posição (linha 0, coluna 0)
    int 0x10                ; Chama BIOS para reposicionar cursor

    popa                   ; Restaura registradores
    ret                    ; Retorna ao chamador
	
	
; ------------------------------------------------------------------
; delay - pequena espera para animação
; ------------------------------------------------------------------
delay:
    push cx
    push dx
    mov cx, 150
.loop1:
    mov dx, 0FFFFh
.loop2:
    dec dx
    jnz .loop2
    dec cx
    jnz .loop1
    pop dx
    pop cx
    ret

; efeito de digitação com cor (LENTO)
type_effect_color:
    push ax
    push si
    push bx
.te_loop:
    lodsb
    cmp al, 0
    je .done
    call print_char_color
    call delay
    jmp .te_loop
.done:
    pop bx
    pop si
    pop ax
    ret
	
