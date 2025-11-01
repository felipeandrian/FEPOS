; ==================================================================
; src/fs/fat12/filename.asm - Files
; ==================================================================

; ------------------------------------------------------------------
; int_filename_convert
; ------------------------------------------------------------------
; Objetivo:
;   Converter um nome de arquivo no formato humano "TEST.BIN"
;   para o formato FAT12 "TEST    BIN" (8.3, com padding de espaços).
;
; Contrato:
;   Entrada:
;     AX = ponteiro para string terminada em zero (ex.: "TEST.BIN")
;   Saída:
;     AX = ponteiro para string convertida no formato FAT12 (8+3+terminador)
;     CF = 0 se sucesso
;     CF = 1 se falha (nome inválido)
;
; Regras de validação:
;   - Nome não pode ser vazio.
;   - Nome não pode exceder 8 caracteres antes do ponto.
;   - Extensão não pode exceder 3 caracteres.
;   - Comprimento total não pode ultrapassar 14 (8+1+3+terminador).
;   - Não pode haver mais de um ponto.
;
; Observação:
;   O destino é um buffer global de 13 bytes:
;     8 (nome) + 3 (extensão) + 1 (terminador nulo) + 1 extra de segurança.
; ------------------------------------------------------------------
int_filename_convert:
    pusha                           ; Salva todos os registradores

    mov si, ax                      ; SI = ponteiro para string de entrada

    ; --------------------------------------------------------------
    ; Etapa 1: Verificar comprimento da string
    ; --------------------------------------------------------------
    call string_length              ; AX = comprimento da string
    cmp ax, 14                      ; Maior que 14? (8+1+3+terminador)
    jg int_filename_convert_failure ; Se sim, inválido
    cmp ax, 0                       ; String vazia?
    je int_filename_convert_failure ; Se sim, inválido

    mov dx, ax                      ; DX = comprimento da string (guardado)

    ; --------------------------------------------------------------
    ; Etapa 2: Preparar destino
    ; --------------------------------------------------------------
    mov di, int_filename_convert_dest_string_var
                                    ; DI = ponteiro para buffer de saída
    mov cx, 0                       ; CX = contador de caracteres do nome

; --------------------------------------------------------------
; Etapa 3: Copiar parte do nome (antes do '.')
; --------------------------------------------------------------
int_filename_convert_copy_loop:
    lodsb                           ; AL = próximo caractere da string
    cmp al, '.'                     ; Encontrou ponto?
    je int_filename_convert_extension_found
    stosb                           ; Copia caractere para destino
    inc cx                          ; Incrementa contador de caracteres do nome

    cmp cx, dx                      ; Já copiou tudo? (sem encontrar '.')
    jge int_filename_convert_failure
    cmp cx, 8                       ; Nome maior que 8 caracteres?
    jge int_filename_convert_failure
    jmp int_filename_convert_copy_loop


; --------------------------------------------------------------
; Etapa 4: Encontrou o ponto (início da extensão)
; --------------------------------------------------------------
int_filename_convert_extension_found:
    cmp cx, 0                       ; Nome vazio antes do ponto?
    je int_filename_convert_failure ; Se sim, inválido

; --------------------------------------------------------------
; Etapa 5: Preencher com espaços até 8 caracteres
; --------------------------------------------------------------
int_filename_convert_add_spaces:
    cmp cx, 8                       ; Já completou 8?
    je int_filename_convert_do_extension
    mov byte [di], ' '              ; Preenche com espaço
    inc di
    inc cx
    jmp int_filename_convert_add_spaces


; --------------------------------------------------------------
; Etapa 6: Copiar extensão (até 3 caracteres)
; --------------------------------------------------------------
int_filename_convert_do_extension:
    mov cx, 3                       ; Extensão tem no máximo 3 chars
int_filename_convert_copy_ext:
    lodsb                           ; AL = próximo caractere
    cmp al, 0                       ; Terminador encontrado?
    je int_filename_convert_pad_ext ; Se sim, precisa preencher com espaços
    cmp al, '.'                     ; Outro ponto encontrado? Inválido
    je int_filename_convert_failure
    stosb                           ; Copia caractere da extensão
    loop int_filename_convert_copy_ext


; --------------------------------------------------------------
; Etapa 7: Verificar se string terminou corretamente
; --------------------------------------------------------------
int_filename_convert_check_end:
    lodsb                           ; Lê próximo caractere
    cmp al, 0                       ; Deve ser terminador nulo
    je int_filename_convert_final_null
    jmp int_filename_convert_failure


; --------------------------------------------------------------
; Etapa 8: Preencher extensão com espaços (se < 3 chars)
; --------------------------------------------------------------
int_filename_convert_pad_ext:
    cmp cx, 0                       ; Já preencheu os 3?
    je int_filename_convert_final_null
    mov byte [di], ' '              ; Preenche com espaço
    inc di
    loop int_filename_convert_pad_ext


; --------------------------------------------------------------
; Etapa 9: Finalizar string convertida
; --------------------------------------------------------------
int_filename_convert_final_null:
    mov byte [di], 0                ; Terminador nulo no final

    popa                            ; Restaura registradores
    mov ax, int_filename_convert_dest_string_var
                                    ; AX = ponteiro para string convertida
    clc                             ; CF = 0 (sucesso)
    ret


; --------------------------------------------------------------
; Falha na conversão
; --------------------------------------------------------------
int_filename_convert_failure:
    popa
    stc                             ; CF = 1 (falha)
    ret


; --------------------------------------------------------------
; Buffer global para string convertida
; --------------------------------------------------------------
; 8 bytes (nome) + 3 bytes (extensão) + 1 terminador = 12
; Reservamos 13 para segurança.
int_filename_convert_dest_string_var times 13 db 0