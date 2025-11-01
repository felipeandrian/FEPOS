; ==================================================================
; src/fs/fat12/directory.asm - Ponto de Entrada do FEP OS
; ==================================================================

; Entrada: DS:SI → string do nome (digitado pelo usuário)
; Saída:   ES:DI → nome convertido (11 bytes no formato FAT 8.3)
; Retorna: ponteiro em AX (apontando para int_buffer)

int_dir_convert:
    pusha                          ; Salva todos os registradores gerais

    mov di, int_buffer             ; DI aponta para o buffer de 11 bytes
    mov cx, 11                     ; Precisamos preencher 11 posições
    mov al, ' '                    ; Preenche com espaços (padrão FAT12)

.fill_spaces:
    mov [di], al                   ; Escreve espaço no buffer
    inc di
    loop .fill_spaces              ; Repete até preencher os 11 bytes

    ; Agora vamos copiar o nome do usuário para o buffer
    mov si, user_input             ; SI aponta para a string original
    mov di, int_buffer             ; DI volta para o início do buffer
    mov cx, 8                      ; Até 8 caracteres para o "nome" (antes do ponto)

.copy_name:
    lodsb                          ; Carrega próximo caractere de [SI] em AL e avança SI
    cmp al, 0                      ; Se for terminador nulo → fim da string
    je .done
    cmp al, '.'                    ; Se encontrar ponto → fim da parte do nome
    je .done
    mov [di], al                   ; Copia caractere para o buffer
    inc di
    loop .copy_name                 ; Continua até 8 caracteres ou até encontrar '.'/0

.done:
    mov ax, int_buffer             ; Retorna ponteiro para o buffer em AX
    popa                           ; Restaura registradores
    ret                            ; Retorna ao chamador

; --------------------------------------------------------------
; Buffers auxiliares
; --------------------------------------------------------------
int_buffer: times 11 db 0          ; Buffer de 11 bytes (8 para nome + 3 para extensão)
user_input: times 64 db 0          ; Buffer de entrada do usuário (até 64 chars)