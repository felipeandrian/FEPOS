; ==============================================================================
; Arquivo:    fat.asm
; Caminho:    src/fs/fat12/fat.asm
; Projeto:    Sistema Operacional / Bootloader (FAT12)
; Autor:      Felipe Andrian Peixoto
; ==============================================================================
; Descrição:
;   Este módulo contém funções de manipulação direta da FAT12 (File Allocation Table),
;   incluindo alocação de clusters, leitura de cadeias de clusters e marcação de fim
;   de arquivo. Ele é utilizado por funções de alto nível como criação de arquivos,
;   diretórios e leitura de dados.
;
; Funções implementadas:
;   - fat_allocate_cluster: encontra e reserva um cluster livre na FAT
;
; Convenções:
;   - A FAT deve estar carregada em memória (ex: disk_buffer) antes de chamar as funções.
;   - Os clusters começam a partir do número 2 (0 e 1 são reservados).
;   - A marca de fim de cadeia é 0xFFF (12 bits).
;
; Dependências:
;   - disk_buffer: buffer onde a FAT está carregada
;   - Funções auxiliares de leitura/escrita de disco (ex: disk_read_fat, disk_write_fat)
;
; Notas:
;   - Este módulo assume que a FAT cabe inteiramente em memória.
;   - Pode ser estendido para FAT16 com ajustes no tamanho das entradas.
; ==============================================================================

; --------------------------------------------------------------------------
; fat_allocate_cluster -- Aloca um cluster livre na FAT12
; --------------------------------------------------------------------------
; Objetivo:
;   Percorre a FAT procurando um cluster livre (valor 0x000),
;   marca esse cluster como fim de cadeia (0xFFF) e retorna seu número.
;
; Contrato:
;   Entrada: nenhuma
;   Saída:
;     AX = número do cluster alocado
;     CF = 0 → sucesso
;     CF = 1 → falha (sem espaço)
;
; Preservação:
;   Usa PUSHA/POPA para preservar registradores
; --------------------------------------------------------------------------

fat_allocate_cluster:
    pusha

    mov ax, 0                   ; FAT está em segmento 0 (assumido)
    mov es, ax
    mov si, disk_buffer         ; SI = início da FAT (offset dentro de ES)
    mov cx, 4085                ; Máximo de clusters em FAT12 (para 1.44MB)
    mov bx, 2                   ; FAT12 começa no cluster 2

.allocate_loop:
    ; --- Calcula posição da entrada FAT12 ---
    mov ax, bx                  ; AX = cluster atual
    mov dx, 0
    mov bp, 3
    mul bp                      ; AX = cluster * 3
    mov bp, 2
    div bp                      ; AX = (3*cluster)/2, DX = paridade
    push dx                     ; Salva paridade (par ou ímpar)
    mov di, si
    add di, ax                  ; DI = posição da entrada FAT

    mov ax, [es:di]             ; Lê 2 bytes da FAT
    pop dx
    cmp dx, 0
    je .check_even
.check_odd:
    shr ax, 4                   ; Ímpar → pega 12 bits altos
    jmp .check_value
.check_even:
    and ax, 0x0FFF              ; Par → pega 12 bits baixos

.check_value:
    cmp ax, 0                   ; Está livre?
    je .found

    inc bx                      ; Próximo cluster
    loop .allocate_loop

    ; --- Nenhum cluster livre encontrado ---
    popa
    stc
    ret

.found:
    ; --- Marca cluster como fim de cadeia (0xFFF) ---
    mov ax, bx
    mov dx, 0
    mov bp, 3
    mul bp
    mov bp, 2
    div bp
    push dx
    mov di, si
    add di, ax
    pop dx

    mov ax, [es:di]
    cmp dx, 0
    je .mark_even
.mark_odd:
    and ax, 0x000F              ; Preserva 4 bits baixos
    or ax, 0xFFF0               ; Marca 12 bits altos como 0xFFF
    mov [es:di], ax
    jmp .done
.mark_even:
    and ax, 0xF000              ; Preserva 4 bits altos
    or ax, 0x0FFF               ; Marca 12 bits baixos como 0xFFF
    mov [es:di], ax

.done:
    mov ax, bx                  ; AX = cluster alocado
    popa
    clc
    ret
	

; --------------------------------------------------------------------------
; fat_write_entry -- Escreve valor na FAT12 para um cluster específico
; IN: BX = número do cluster
;     AX = valor a ser escrito (12 bits)
; OUT: Carry = 0 (sucesso), 1 (falha)
; nao sei se ta funcionando essa porra nao o cd nao esta indo depuracao need
; --------------------------------------------------------------------------
fat_write_entry:
    pusha

    ; Calcula offset na FAT
    mov dx, bx
    shl dx, 1         ; dx = cluster * 2
    add dx, bx        ; dx = cluster * 3
    shr dx, 1         ; dx = cluster * 1.5

    mov si, dx        ; SI = offset na FAT
    mov di, fat_buffer

    ; Calcula endereço base: di + si → bx
    mov bx, di
    add bx, si

    ; Verifica se cluster é par ou ímpar
    test bx, 1
    jz .even

    ; Ímpar: escreve 12 bits cruzados
    ; byte 0 = low 8 bits
    mov [bx], al

    ; byte 1 = high 4 bits
    mov dl, ah
    and dl, 0x0F
    mov al, [bx+1]
    and al, 0xF0
    or al, dl
    mov [bx+1], al
    jmp .done

.even:
    ; Par: escreve 12 bits diretos
    ; byte 0 = low 8 bits
    mov [bx], al

    ; byte 1 = high 4 bits
    mov dl, ah
    shl dl, 4
    mov al, [bx+1]
    and al, 0x0F
    or al, dl
    mov [bx+1], al

.done:
    popa
    clc
    ret
	
fat_buffer equ 0x8000

