; ==================================================================
; src/lib/strings.asm - Manipulação de Strings
; ==================================================================

; --------------------------------------------------------------
; string_length
; --------------------------------------------------------------
; Objetivo:
;   Calcular o comprimento (número de caracteres) de uma string
;   terminada em zero (null-terminated).
;
; Contrato:
;   Entrada:
;     AX = endereço base (offset) da string (assume DS já configurado)
;   Saída:
;     AX = comprimento da string (número de bytes antes do 0)
;   Preservação:
;     Demais registradores são preservados (usa pusha/popa).
;
; Observações:
;   - A string deve terminar com byte 0 (terminador nulo).
;   - Não conta o terminador; apenas os bytes válidos antes do 0.
;   - Usa BX como ponteiro de leitura e CX como contador.
; --------------------------------------------------------------
string_length:
    pusha                       ; Salva AX, BX, CX, DX, SI, DI, BP, SP

    mov bx, ax                  ; BX = endereço da string
                                ; Racional: usamos BX para indexar [BX]

    mov cx, 0                   ; CX = contador de caracteres (inicializa em 0)

.loop:
    cmp byte [bx], 0            ; Verifica se o byte atual é 0 (fim da string)
    je .done                    ; Se for 0, terminou: vai para .done
    inc bx                      ; Avança para próximo byte
    inc cx                      ; Incrementa o contador
    jmp .loop                   ; Continua até encontrar 0

.done:
    mov word [.tmp_counter], cx ; Armazena o contador em memória temporária
                                ; Necessário porque popa vai restaurar CX

    popa                        ; Restaura todos os registradores salvos

    mov ax, [.tmp_counter]      ; AX = comprimento calculado
    ret                         ; Retorna ao chamador

    ; Variável temporária (local ao módulo)
    .tmp_counter dw 0           ; Armazena comprimento entre popa e retorno



; --------------------------------------------------------------
; string_compare
; --------------------------------------------------------------
; Objetivo:
;   Comparar duas strings terminadas em 0 (null-terminated) por igualdade exata.
;   Considera igualdade quando:
;     - Todos os caracteres correspondem posição a posição, e
;     - Ambos os ponteiros chegam ao terminador nulo ao mesmo tempo.
;
; Contrato:
;   Entrada:
;     SI = endereço da primeira string (DS:SI)
;     DI = endereço da segunda string (DS:DI)
;   Saída:
;     AL = 1 se são iguais
;     AL = 0 se são diferentes
;   Preservação:
;     SI e DI são preservados com push/pop.
;
; Observações:
;   - Comparação case-sensitive (não altera letras).
;   - Para diferenciar "prefixos" (ex.: "ab" vs "abc"):
;     quando um terminador é encontrado, apenas é igual se o outro também for 0.
; --------------------------------------------------------------
string_compare:
    push si                     ; Preserva ponteiros de entrada
    push di

sc_loop:
    mov al, [si]                ; Lê próximo caractere da primeira string
    mov bl, [di]                ; Lê próximo caractere da segunda string

    cmp al, bl                  ; Compara caracteres atuais
    jne sc_not_equal            ; Se diferentes, strings não são iguais

    cmp al, 0                   ; Se caractere atual é 0 (terminador)
    je sc_equal                 ; E como são iguais, ambos são 0 => fim e igualdade

    inc si                      ; Avança para próximo caractere na primeira string
    inc di                      ; Avança na segunda string
    jmp sc_loop                 ; Continua a comparação

sc_equal:
    pop di                      ; Restaura DI
    pop si                      ; Restaura SI
    mov al, 1                   ; Retorno: iguais
    ret

sc_not_equal:
    pop di
    pop si
    mov al, 0                   ; Retorno: diferentes
    ret


; --------------------------------------------------------------
; Função: string_uppercase
; --------------------------------------------------------------
; Objetivo:
;   Converte todos os caracteres de uma string terminada em zero
;   (null-terminated string) para MAIÚSCULAS, no próprio lugar.
;
; Entrada:
;   AX = ponteiro para a string
; Saída:
;   A string original é modificada em memória, convertida para maiúsculas.
;   AX continua contendo o ponteiro original.
; Preserva:
;   Todos os registradores do chamador (graças ao PUSHA/POPA).
; --------------------------------------------------------------

string_uppercase:
    pusha                   ; Salva todos os registradores gerais
    mov si, ax              ; SI = ponteiro para a string

su_more:
    mov al, [si]            ; Lê caractere atual
    cmp al, 0               ; É o terminador nulo?
    je su_done ; Se sim, fim da string → sai

    ; ----------------------------------------------------------
    ; Teste se o caractere está no intervalo 'a'..'z'
    ; ----------------------------------------------------------
    cmp al, 'a'             ; É menor que 'a'?
    jb su_noatoz ; Se sim, não é letra minúscula
    cmp al, 'z'             ; É maior que 'z'?
    ja su_noatoz ; Se sim, também não é minúscula

    ; ----------------------------------------------------------
    ; Se chegou aqui, AL  ['a'..'z']
    ; Converte para maiúscula subtraindo 0x20
    ; (diferença entre ASCII 'a' (0x61) e 'A' (0x41))
    ; ----------------------------------------------------------
    sub byte [si], 0x20     ; Converte no local

su_noatoz:
    inc si                  ; Avança para próximo caractere
    jmp su_more ; Continua o loop

su_done:
    popa                    ; Restaura todos os registradores
    ; AX já contém o ponteiro original
    ret
	
	
; ------------------------------------------------------------------
; string_parse
; ------------------------------------------------------------------
; Objetivo:
;   Receber uma string contendo palavras separadas por espaços
;   (ex: "run foo bar baz") e retornar ponteiros para cada palavra
;   como strings terminadas em zero (null-terminated).
;
; Contrato:
;   Entrada:
;     SI = endereço da string original (DS:SI)
;   Saída:
;     AX = ponteiro para a 1ª palavra ("run")
;     BX = ponteiro para a 2ª palavra ("foo")
;     CX = ponteiro para a 3ª palavra ("bar")
;     DX = ponteiro para a 4ª palavra ("baz")
;   Preservação:
;     SI é preservado com push/pop.
;
; Observações:
;   - A string original é modificada: os espaços são substituídos por 0.
;   - As palavras são separadas in-place, sem alocação extra.
;   - A função suporta até 4 palavras (AX, BX, CX, DX).
;   - Usa LODSB para leitura sequencial de bytes.
; ------------------------------------------------------------------

string_parse:
    push si                     ; Preserva SI (ponteiro da string original)

    mov ax, si                  ; AX aponta para o início da 1ª palavra

    mov bx, 0                   ; Inicializa os demais ponteiros como vazios
    mov cx, 0
    mov dx, 0

    push ax                     ; Salva AX temporariamente (será restaurado no final)

; -------------------------------
; sp_loop1: Localiza fim da 1ª palavra
; -------------------------------
sp_loop1:
    lodsb                       ; Lê próximo byte da string (AL ← [SI], SI++)
    cmp al, 0                   ; Fim da string?
    je sp_finish                ; Se sim, termina
    cmp al, ' '                 ; Encontrou espaço?
    jne sp_loop1                ; Se não, continua lendo
    dec si                      ; Volta para o espaço
    mov byte [si], 0            ; Substitui espaço por 0 (terminador da 1ª palavra)

    inc si                      ; SI agora aponta para início da 2ª palavra
    mov bx, si                  ; BX ← ponteiro da 2ª palavra

; -------------------------------
; sp_loop2: Localiza fim da 2ª palavra
; -------------------------------
sp_loop2:
    lodsb
    cmp al, 0
    je sp_finish
    cmp al, ' '
    jne sp_loop2
    dec si
    mov byte [si], 0            ; Termina a 2ª palavra

    inc si
    mov cx, si                  ; CX ← ponteiro da 3ª palavra

; -------------------------------
; sp_loop3: Localiza fim da 3ª palavra
; -------------------------------
sp_loop3:
    lodsb
    cmp al, 0
    je sp_finish
    cmp al, ' '
    jne sp_loop3
    dec si
    mov byte [si], 0            ; Termina a 3ª palavra

    inc si
    mov dx, si                  ; DX ← ponteiro da 4ª palavra

; -------------------------------
; Finalização
; -------------------------------
sp_finish:
    pop ax                      ; Restaura AX (ponteiro da 1ª palavra)
    pop si                      ; Restaura SI
    ret                         ; Retorna com AX, BX, CX, DX apontando para as palavras
	
	
; ==================================================================
; string_search
; ==================================================================
; Objetivo:
;   Procurar uma substring (agulha) dentro de uma string maior (palheiro).
;   Ambas devem ser strings terminadas em zero (null-terminated).
;
; Contrato:
;   Entrada:
;     SI = ponteiro para a string "palheiro" (ex: "linha de texto")
;     DI = ponteiro para a string "agulha"   (ex: "texto")
;   Saída:
;     CF = 0 (Clear) se a agulha FOI encontrada no palheiro
;     CF = 1 (Set)   se a agulha NÃO foi encontrada
;   Preservação:
;     SI, DI e CX são preservados com push/pop.
;
; Observações:
;   - A busca é sensível a maiúsculas/minúsculas (case-sensitive).
;   - A função percorre o palheiro caractere por caractere,
;     tentando casar a agulha a partir de cada posição.
;   - Se a agulha for vazia (primeiro byte = 0), retorna "não encontrada".
; ==================================================================

string_search:
    push si                     ; Salva ponteiros originais
    push di
    push cx                     ; Salva registrador de trabalho

; --------------------------------------------------
; ss_outer_loop: percorre o palheiro caractere a caractere
; --------------------------------------------------
ss_outer_loop:
    mov ch, [si]                ; Lê caractere atual do palheiro
    cmp ch, 0                   ; Fim do palheiro?
    je ss_not_found             ; Se sim, agulha não foi encontrada

    mov cl, [di]                ; Lê primeiro caractere da agulha
    cmp cl, 0
    je ss_not_found_empty_needle ; Agulha vazia → não considerar encontrada

    cmp ch, cl                  ; Compara caractere atual com início da agulha
    jne ss_next_haystack_char   ; Se não bater, avança no palheiro

    ; --- Possível início de correspondência ---
    push si                     ; Salva posição atual do palheiro
    push di                     ; Salva posição atual da agulha

; --------------------------------------------------
; ss_inner_loop: compara sequência de caracteres
; --------------------------------------------------
ss_inner_loop:
    inc si                      ; Avança no palheiro
    inc di                      ; Avança na agulha

    mov cl, [di]                ; Verifica próximo caractere da agulha
    cmp cl, 0
    je ss_found                 ; Se fim da agulha, correspondência completa

    mov ch, [si]                ; Verifica próximo caractere do palheiro
    cmp ch, 0
    je ss_inner_fail            ; Se fim do palheiro, falhou

    cmp ch, cl
    je ss_inner_loop            ; Se caracteres batem, continua

; --------------------------------------------------
; ss_inner_fail: falha na correspondência parcial
; --------------------------------------------------
ss_inner_fail:
    pop di                      ; Restaura ponteiros
    pop si
    jmp ss_next_haystack_char  ; Tenta próxima posição no palheiro

; --------------------------------------------------
; ss_next_haystack_char: avança no palheiro
; --------------------------------------------------
ss_next_haystack_char:
    inc si
    jmp ss_outer_loop

; --------------------------------------------------
; ss_found: correspondência completa encontrada
; --------------------------------------------------
ss_found:
    pop di                      ; Limpa pilha (inner_loop)
    pop si
    pop cx                      ; Restaura registradores
    pop di
    pop si
    clc                         ; CF = 0 (sucesso)
    ret

; --------------------------------------------------
; ss_not_found / ss_not_found_empty_needle: falha
; --------------------------------------------------
ss_not_found_empty_needle:
ss_not_found:
    pop cx                      ; Restaura registradores
    pop di
    pop si
    stc                         ; CF = 1 (falha)
    ret
