; ==================================================================
; src/lib/stdlib.asm - Utilidades
; ==================================================================
	
; --------------------------------------------------------------
; Função: bcd_to_ascii
; --------------------------------------------------------------
; Entrada:
;   AL = valor em BCD (exemplo: 0x23 representa o número decimal 23)
; Saída:
;   string_buff = "23", terminado em 0 (null-terminated string)
; Uso:
;   Converte um byte BCD em dois caracteres ASCII ('0'..'9')
; --------------------------------------------------------------

bcd_to_ascii:
    push ax                 ; Salva AX (pois vamos manipular AL e AH)
    push bx                 ; Salva BX (será usado como ponteiro para buffer)

    mov ah, al              ; Copia AL para AH (vamos separar os nibbles)
    and ah, 0F0h            ; Isola o nibble alto (bits 7-4)
    shr ah, 4               ; Desloca para a direita → agora AH contém o dígito alto (0-9)

    and al, 0Fh             ; Isola o nibble baixo (bits 3-0) → dígito baixo (0-9)

    mov bx, string_buff     ; BX aponta para o buffer de saída

    ; Converte nibble alto em ASCII
    add ah, '0'             ; Transforma valor 0-9 em caractere '0'-'9'
    mov [bx], ah            ; Armazena no primeiro byte do buffer

    ; Converte nibble baixo em ASCII
    add al, '0'             ; Transforma valor 0-9 em caractere '0'-'9'
    mov [bx+1], al          ; Armazena no segundo byte do buffer

    ; Finaliza string com terminador nulo
    mov byte [bx+2], 0      ; Coloca 0 no final → string C-style

    pop bx                  ; Restaura BX
    pop ax                  ; Restaura AX
    ret                     ; Retorna ao chamador

; --------------------------------------------------------------
; Buffer de saída (3 bytes: 2 dígitos + terminador nulo)
; --------------------------------------------------------------
string_buff db 3 dup(0)



; --------------------------------------------------------------
; Função: word_to_ascii
; --------------------------------------------------------------
; Entrada:
;   BX = número inteiro sem sinal (0–65535)
; Saída:
;   string_buff_word = representação decimal em ASCII, terminada em 0
; Observação:
;   O buffer precisa ter pelo menos 6 bytes (5 dígitos + terminador nulo).
; --------------------------------------------------------------

word_to_ascii:
    push ax                 ; Salva registradores usados
    push bx
    push cx
    push dx

    mov cx, 0               ; CX = contador de dígitos
    mov si, string_buff_word ; SI aponta para o buffer de saída

wta_convert_loop:
    xor dx, dx              ; Zera DX (necessário para divisão 16 bits / 16 bits)
    mov ax, bx              ; AX = número atual
    mov bx, 10              ; Divisor = 10
    div bx                  ; Divide DX:AX por BX
                            ; AX = quociente, DX = resto (0–9)

    push dx                 ; Empilha o resto (dígito menos significativo)
    mov bx, ax              ; BX = quociente → próximo número a dividir
    inc cx                  ; Incrementa contador de dígitos
    cmp bx, 0               ; Se quociente != 0, continua dividindo
    jne wta_convert_loop

wta_print_digits:
    pop dx                  ; Recupera último resto empilhado
    add dl, '0'             ; Converte valor 0–9 em caractere ASCII
    mov [si], dl            ; Armazena no buffer
    inc si                  ; Avança ponteiro do buffer
    loop wta_print_digits      ; Repete até imprimir todos os dígitos

    mov byte [si], 0        ; Finaliza string com terminador nulo

    ; --------------------------------------------------------------
    ; Restauração do estado original
    ; --------------------------------------------------------------
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------
; Buffer de saída (6 bytes: até 5 dígitos + terminador nulo)
; --------------------------------------------------------------
string_buff_word db 6 dup(0)


; ==================================================================
; Funções para Impressão em Hexadecimal
; ==================================================================

; --------------------------------------------------------------
; print_hex_word
; --------------------------------------------------------------
; Objetivo:
;   Imprimir o conteúdo do registrador AX em formato hexadecimal
;   de 16 bits (4 dígitos hexadecimais).
;
; Exemplo:
;   Se AX = 0x1234, a saída será: "0x1234"
; Observação:
;   - Um "nibble" é metade de um byte (4 bits).
;   - Um valor de 16 bits (AX) contém 4 nibbles.
; --------------------------------------------------------------

print_hex_word:
    pusha                   ; Salva todos os registradores gerais (AX, CX, DX, BX, SP, BP, SI, DI)
                            ; Isso garante que a rotina não altere o estado do programa chamador.

    ; --------------------------------------------------------------
    ; Recuperando o valor original de AX
    ; --------------------------------------------------------------
    ; O "pusha" empilha os registradores na seguinte ordem:
    ;   [SP]   = AX
    ;   [SP+2] = CX
    ;   [SP+4] = DX
    ;   [SP+6] = BX
    ;   [SP+8] = SP original
    ;   [SP+10]= BP
    ;   [SP+12]= SI
    ;   [SP+14]= DI
    ;
    ; Como acabamos de executar "pusha", o SP aponta para o AX salvo.
    ; Para acessar esse valor, movemos SP para BP e lemos [BP+14].
    ; (isso porque a convenção varia, mas aqui o comentário indica que
    ; o AX original está nesse deslocamento).
    ; --------------------------------------------------------------

    mov bp, sp
    mov ax, [bp+14]          ; Recupera o valor de AX que queremos imprimir em hexadecimal.

    ; --------------------------------------------------------------
    ; Impressão do valor em hexadecimal (4 dígitos hex = 16 bits)
    ; --------------------------------------------------------------
    ; A ideia é imprimir cada nibble (4 bits) separadamente, da esquerda
    ; para a direita: nibble 3 (mais significativo) até nibble 0 (menos significativo).
    ; --------------------------------------------------------------

    ; --- Nibble 3 (bits 12-15) ---
    push ax                  ; Salva AX para não perder o valor original
    mov cl, 12
    shr ax, cl               ; Desloca 12 bits à direita → bits 12-15 vão para posição 0-3
    call print_hex_nibble    ; Imprime o nibble (0-F)
    pop ax                   ; Restaura AX

    ; --- Nibble 2 (bits 8-11) ---
    push ax
    mov cl, 8
    shr ax, cl               ; Desloca 8 bits → bits 8-11 agora em 0-3
    and al, 0x0F             ; Isola apenas os 4 bits menos significativos
    call print_hex_nibble    ; Imprime nibble 2
    pop ax

    ; --- Nibble 1 (bits 4-7) ---
    push ax
    mov cl, 4
    shr ax, cl               ; Desloca 4 bits → bits 4-7 agora em 0-3
    and al, 0x0F             ; Isola nibble
    call print_hex_nibble    ; Imprime nibble 1
    pop ax

    ; --- Nibble 0 (bits 0-3) ---
    push ax
    and al, 0x0F             ; Isola os 4 bits menos significativos
    call print_hex_nibble    ; Imprime nibble 0
    pop ax

    ; --------------------------------------------------------------
    ; Finalização
    ; --------------------------------------------------------------
    popa                     ; Restaura todos os registradores salvos no início
    ret                      ; Retorna ao chamador

; --------------------------------------------------------------
; print_hex_byte
; --------------------------------------------------------------
; Objetivo:
;   Imprimir o conteúdo de AL em formato hexadecimal de 8 bits
;   (2 dígitos hexadecimais).
;
; Exemplo:
;   Se AL = 0xAB, a saída será: "AB"
;
; Estratégia:
;   1) Separar o byte em dois nibbles (alto e baixo).
;   2) Converter cada nibble em caractere ASCII ('0'–'9' / 'A'–''F').
;   3) Imprimir primeiro o nibble alto, depois o nibble baixo.
;
; Detalhes:
;   - Um "nibble" é composto por 4 bits. Um byte possui 2 nibbles:
;     [7..4] (alto) e [3..0] (baixo).
;   - O nibble alto é obtido deslocando AL 4 bits à direita (SHR AL, 4).
;   - O nibble baixo é obtido mascarando AL com 0x0F (AND AL, 0x0F).
;   - A rotina print_hex_nibble recebe AL no intervalo [0..15] e imprime
;     o dígito correspondente em base 16.
; --------------------------------------------------------------
print_hex_byte:
    pusha                   ; Preserva os registradores do chamador
                            ; (AX, BX, CX, DX, SI, DI, BP, SP)

    mov ah, al              ; Salva o valor original do byte em AH
                            ; Racional: AL será modificado para extrair nibbles

    ; --- Nibble alto (bits 7..4) ---
    ; Exemplo: se AL = 0xAB (1010 1011b), após SHR AL,4 => 0x0A (0000 1010b)
    shr al, 4               ; Desloca o byte 4 bits à direita,
                            ; trazendo o nibble alto para a posição baixa (0..3)
    ; Agora AL contém um valor entre 0 e 15 (0x0..0xF)
    call print_hex_nibble   ; Converte esse valor para '0'..'9' ou 'A'..'F' e imprime

    ; --- Nibble baixo (bits 3..0) ---
    ; Recupera o byte original e isola os 4 bits inferiores
    mov al, ah              ; Restaura o valor original do byte
    and al, 0x0F            ; Zera os 4 bits superiores, mantém apenas o nibble baixo
                            ; Exemplo: 0xAB AND 0x0F => 0x0B
    call print_hex_nibble   ; Converte/imprime o nibble baixo

    popa                    ; Restaura registradores
    ret                     ; Retorna ao chamador

; --------------------------------------------------------------
; print_hex_nibble
; --------------------------------------------------------------
; Objetivo:
;   Converter um valor de 0 a 15 (em AL) para o caractere ASCII
;   correspondente em base 16 e imprimir na tela:
;     0..9  -> '0'..'9'
;     10..15 -> 'A'..'F'
;
; Entradas:
;   AL = valor no intervalo [0..15]
;
; Saídas:
;   Exibe um único caractere ASCII via print_char (INT 10h/0Eh),
;   preservando o estado dos registradores do chamador.
;
; Estratégia:
;   - Comparar AL com 9:
;       * Se AL <= 9: somar '0' (0x30) para obter '0'..'9'.
;       * Se AL > 9: somar ('A' - 10) para mapear 10..15 em 'A'..'F'.
;   - Chamar print_char para exibição.
;
; Observação:
;   - O uso de push/pop ao redor de print_char protege AX, já que
;     print_char internamente usa pusha/popa, mas garantir a
;     integridade de AL após a conversão mantém a rotina previsível.
; --------------------------------------------------------------
print_hex_nibble:
    cmp al, 9               ; Compara AL com 9
    jle print_hex_nibble_digit
    ; Caminho para valores 10..15
    add al, 'A' - 10        ; 10->'A', 11->'B', ..., 15->'F'
    jmp print_hex_nibble_print

print_hex_nibble_digit:
    ; Caminho para valores 0..9
    add al, '0'             ; 0->'0', 1->'1', ..., 9->'9'

print_hex_nibble_print:
    push ax                 ; Protege AX ao chamar print_char
    call print_char         ; Exibe o caractere atualmente em AL (teletipo BIOS)
    pop ax
    ret
	

; ==================================================================
;  print_dword_dec
; ==================================================================
; Objetivo: imprimir um valor unsigned de 32 bits em decimal.
; Convenção de entrada: DX:AX contém o número (DX = high word, AX = low word).
; Estratégia: divisão iterativa por 10, empilhando dígitos ASCII em um buffer local,
; depois imprimir do mais significativo para o menos significativo.

print_dword_dec:
    pusha                   ; Salva todos os registradores gerais (AX, CX, DX, BX, SP, BP, SI, DI)
    push ds                 ; Salva DS (caso haja uso de segmentos/data durante impressão)

    ; --------------------------------------------------------------
    ; Criação de "stack frame" local para buffer de dígitos
    ; --------------------------------------------------------------
    ; Usamos espaço local na pilha para armazenar os dígitos em ASCII.
    ; Cada dígito vai de '0' a '9'. O número máximo de dígitos de 32 bits é 10 (4294967295).
    ; Aqui reservamos 12 bytes por segurança (10 dígitos + margem).
    mov bp, sp              ; BP referencia o estado atual da pilha
    sub sp, 12              ; Aloca 12 bytes: buffer em [bp-12] ... [bp-1]

    ; Mapa dos registradores salvos por PUSHA (acima do DS salvo):
    ; [bp+2] = DI, [bp+4] = SI, [bp+6] = BP_orig, [bp+8] = SP_orig,
    ; [bp+10] = BX, [bp+12] = DX (high), [bp+14] = CX, [bp+16] = AX (low)

    ; --------------------------------------------------------------
    ; Caso base: número igual a zero
    ; --------------------------------------------------------------
    mov dx, [bp+12]         ; Recupera DX original (high word)
    mov ax, [bp+16]         ; Recupera AX original (low word)
    mov cx, dx              ; CX = high
    or  cx, ax              ; Se high|low == 0 então número é zero
    jnz print_dword_dec_do_division

    ; Se for zero, imprime '0' e finaliza
    mov al, '0'
    call print_char
    jmp print_dword_dec_cleanup

print_dword_dec_do_division:
    mov cx, 0               ; CX = contador de dígitos acumulados no buffer
    mov bx, 10              ; Divisor decimal

    ; DI aponta para o fim do buffer (vamos preencher de trás para frente)
    lea di, [bp-1]          ; DI = posição final do buffer local

print_dword_dec_div_loop:
    ; --------------------------------------------------------------
    ; Laço principal: divide DX:AX por 10 (unsigned).
    ; Empilha o dígito menos significativo (resto da divisão) no buffer.
    ; Atualiza DX:AX com o quociente para a próxima iteração.
    ; --------------------------------------------------------------

    ; Teste de término: se o quociente atual (DX:AX) já é zero, imprime o buffer
    mov dx, [bp+12]         ; DX atual
    mov ax, [bp+16]         ; AX atual
    mov si, dx
    or  si, ax
    jz  print_dword_dec_print_digits

    ; --------------------------------------------------------------
    ; Divisão de 32 bits por 10:
    ; 1) Dividir o high word (DX) por 10 para obter um quociente alto (novo DX)
    ;    e um resto alto (propagado para compor o dividendo da próxima etapa).
    ; 2) Dividir (resto alto * 65536 + low word) por 10 para obter quociente baixo (novo AX)
    ;    e resto final (um dígito 0..9).
    ; --------------------------------------------------------------

    ; Salva o high word original temporariamente (para referência se necessário)
    push dx

    ; Passo 1: quociente alto e resto alto
    mov ax, dx              ; AX = high
    xor dx, dx              ; Zera DX para a divisão unsigned DX:AX / BX
    div bx                  ; AX = high / 10 (quociente alto), DX = high % 10 (resto alto)
    mov si, ax              ; SI = novo DX (quociente alto)

    ; Passo 2: quociente baixo e resto final
    pop ax                  ; Recupera high original (comentário original avisava mudança de stack;
                            ; aqui usamos AX apenas como registro livre pós-pop)
    mov ax, [bp+16]         ; AX = low atual (dividendo baixo)
    ; DX ainda contém o resto alto (0..9), compondo (resto_alto:AX) como dividendo
    div bx                  ; AX = novo low (quociente baixo), DX = resto final (0..9)

    ; Converte resto final em ASCII e guarda no buffer
    add dl, '0'             ; DL (resto) -> '0'..'9'
    mov [di], dl            ; Escreve dígito no fim do buffer
    dec di                  ; Move para a posição anterior do buffer
    inc cx                  ; Incrementa contador de dígitos

    ; Atualiza DX:AX com o quociente para próxima iteração
    mov [bp+12], si         ; novo DX = quociente alto
    mov [bp+16], ax         ; novo AX = quociente baixo

    jmp print_dword_dec_div_loop

print_dword_dec_print_digits:
    ; --------------------------------------------------------------
    ; Impressão dos dígitos acumulados
    ; O primeiro dígito a imprimir está em (DI + 1), pois DI aponta
    ; para a última célula não usada no buffer.
    ; --------------------------------------------------------------
    mov si, di              ; SI = última posição não usada
    inc si                  ; SI = primeiro dígito válido

    cmp cx, 0               ; Se não acumulou dígitos, número era 0 (já tratado)
    je  print_dword_dec_cleanup

print_dword_dec_print_loop:
    mov al, [si]            ; Carrega dígito ASCII
    call print_char         ; Imprime no console
    inc si
    loop print_dword_dec_print_loop  ; Decrementa CX e continua enquanto CX != 0

print_dword_dec_cleanup:
    mov sp, bp              ; Libera o buffer local (restaura SP antes do sub sp, 12)

print_dword_dec_done_final:
    pop ds                  ; Restaura DS
    popa                    ; Restaura todos os registradores
    ret
