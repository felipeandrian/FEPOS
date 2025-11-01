
; --------------------------------------------------------------------------
; write_file -- Salva (máx. 64K) um arquivo no disquete (FAT12)
; --------------------------------------------------------------------------
; Objetivo:
;   Gravar um arquivo no disquete formatado com FAT12.
;   Cria entrada no diretório raiz, aloca clusters na FAT e grava os dados.
;
; Contrato:
;   Entrada:
;     AX = ponteiro para nome do arquivo (ASCIIZ)
;     BX = endereço de origem dos dados na RAM (endereço linear)
;     CX = tamanho do arquivo em bytes
;   Saída:
;     Carry Flag = 0 (sucesso), 1 (falha)
;   Preservação:
;     Usa PUSHA/POPA para salvar todos os registradores
;
; Observações:
;   - Não sobrescreve arquivos existentes
;   - Usa FAT12 com clusters de 512 bytes
;   - Suporta até 128 clusters (máx. 64 KB)
; --------------------------------------------------------------------------

write_file:
    pusha

    ; --- Verifica nome válido ---
    mov si, ax
    call string_length
    cmp ax, 0
    je write_file_failure        ; Nome vazio → erro
    mov ax, si                   ; Restaura ponteiro

    ; --- Converte nome para FAT 8.3 ---
    call string_uppercase       ; Converte para maiúsculas
    call int_filename_convert   ; Converte para formato FAT 8.3
    jc write_file_failure       ; Se falhar, aborta

    ; --- Salva parâmetros globais ---
    mov word [write_file_filesize], cx
    mov word [write_file_location], bx
    mov word [write_file_filename], ax

    ; --- Verifica se já existe ---
    call file_exists
    jnc write_file_failure       ; Se já existe, não sobrescreve

    ; --- Limpa tabela de clusters livres ---
    pusha
    mov di, write_file_free_clusters
    mov cx, 128
write_file_clean_free_loop:
    mov word [di], 0
    add di, 2
    loop write_file_clean_free_loop
    popa

    ; --- Calcula clusters necessários ---
    mov ax, cx
    xor dx, dx
    mov bx, 512
    div bx                        ; AX = número de clusters
    cmp dx, 0
    jz write_file_carry_on
    inc ax                        ; Se houver resto, precisa de mais um cluster
write_file_carry_on:
    mov word [write_file_clusters_needed], ax

    ; --- Cria entrada vazia no root ---
    mov ax, [write_file_filename]
    call create_file
    jc write_file_failure

    ; --- Se tamanho = 0, só cria entrada ---
    mov bx, [write_file_filesize]
    cmp bx, 0
    je write_file_finished_zero

    ; --- Lê FAT ---
    call disk_read_fat
    mov si, disk_buffer+3         ; Pula os clusters reservados

    ; --- Procura clusters livres ---
    mov bx, 2                     ; Começa no cluster 2
    mov cx, [write_file_clusters_needed]
    xor dx, dx                    ; Offset em free_clusters

write_file_find_free_cluster:
    lodsw
    and ax, 0FFFh
    jz write_file_found_free_even

write_file_more_odd:
    inc bx
    dec si
    lodsw
    shr ax, 4
    jz write_file_found_free_odd

write_file_more_even:
    inc bx
    jmp write_file_find_free_cluster

write_file_found_free_even:
    push si
    mov si, write_file_free_clusters
    add si, dx
    mov word [si], bx
    pop si
    dec cx
    jz write_file_finished_list
    add dx, 2
    jmp write_file_more_odd

write_file_found_free_odd:
    push si
    mov si, write_file_free_clusters
    add si, dx
    mov word [si], bx
    pop si
    dec cx
    jz write_file_finished_list
    add dx, 2
    jmp write_file_more_even

; --------------------------------------------------------------------------
; Cria cadeia de clusters na FAT
; --------------------------------------------------------------------------
write_file_finished_list:
    xor cx, cx
    mov word [write_file_count], 1

write_file_chain_loop:
    mov ax, [write_file_count]
    cmp ax, [write_file_clusters_needed]
    je write_file_last_cluster

    mov di, write_file_free_clusters
    add di, cx
    mov bx, [di]

    ; Calcula posição na FAT
    mov ax, bx
    xor dx, dx
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]

    or dx, dx
    jz write_file_even

write_file_odd:
    and ax, 000Fh
    mov di, write_file_free_clusters
    add di, cx
    mov bx, [di+2]
    shl bx, 4
    add ax, bx
    mov word [ds:si], ax
    inc word [write_file_count]
    add cx, 2
    jmp write_file_chain_loop

write_file_even:
    and ax, 0F000h
    mov di, write_file_free_clusters
    add di, cx
    mov bx, [di+2]
    add ax, bx
    mov word [ds:si], ax
    inc word [write_file_count]
    add cx, 2
    jmp write_file_chain_loop

; --------------------------------------------------------------------------
; Último cluster da cadeia
; --------------------------------------------------------------------------
write_file_last_cluster:
    mov di, write_file_free_clusters
    add di, cx
    mov bx, [di]

    mov ax, bx
    xor dx, dx
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    mov si, disk_buffer
    add si, ax
    mov ax, word [ds:si]

    or dx, dx
    jz write_file_even_last

write_file_odd_last:
    and ax, 000Fh
    add ax, 0FF80h
    jmp write_file_finito

write_file_even_last:
    and ax, 0F000h
    add ax, 0FF8h

write_file_finito:
    mov word [ds:si], ax
    call disk_write_fat

; --------------------------------------------------------------------------
; Grava dados nos clusters
; --------------------------------------------------------------------------
    xor cx, cx
write_file_save_loop:
    mov di, write_file_free_clusters
    add di, cx
    mov ax, [di]
    cmp ax, 0
    je write_file_write_root_entry

    add ax, 31
    call lba_to_chs

    push cx
    push dx

    mov ax, [write_file_location]
    xor dx, dx
    mov si, 16
    div si
    mov es, ax
    mov bx, dx

    pop dx
    pop cx

    mov ah, 3
    mov al, 1
    stc
    int 13h

    add word [write_file_location], 512
    add cx, 2
    jmp write_file_save_loop

; --------------------------------------------------------------------------
; Atualiza entrada no root dir
; --------------------------------------------------------------------------
write_file_write_root_entry:
    call disk_read_root_dir
    mov ax, es
    mov ds, ax
    mov di, disk_buffer

    mov ax, [write_file_filename]
    call disk_get_root_entry
    jc write_file_failure

    mov ax, [write_file_free_clusters]
    mov word es:[di+26], ax
    mov cx, [write_file_filesize]
    mov word es:[di+28], cx
    mov byte es:[di+30], 0
    mov byte es:[di+31], 0

    call disk_write_root_dir

write_file_finished_zero:
    popa
    clc
    ret

write_file_failure:
    popa
    stc
    ret


; --------------------------------------------------------------------------
; remove_file -- Remove (apaga) o arquivo especificado do sistema de arquivos
; --------------------------------------------------------------------------
; Objetivo:
;   Apagar um arquivo do sistema FAT12, removendo sua entrada no diretório raiz
;   e liberando os clusters ocupados na FAT.
;
; Contrato:
;   Entrada:
;     AX = ponteiro para nome do arquivo (ASCIIZ)
;   Saída:
;     Carry Flag = 0 (sucesso), 1 (falha)
;   Preservação:
;     Usa PUSHA/POPA para salvar todos os registradores
;
; Observações:
;   - O nome é convertido para maiúsculas e formato FAT 8.3.
;   - A entrada no diretório é marcada como apagada (0xE5).
;   - Os clusters são liberados na FAT, zerando os ponteiros da cadeia.
; --------------------------------------------------------------------------

remove_file:
    pusha                           ; Salva todos os registradores

    ; --- Conversão do nome ---
    call string_uppercase           ; Converte string para maiúsculas
    call int_filename_convert       ; Converte para formato FAT12 8.3
    push ax                         ; Guarda ponteiro do nome convertido

    clc                             ; Assume sucesso inicial

    ; --- Lê diretório raiz ---
    call disk_read_root_dir         ; Carrega root dir em disk_buffer
    mov di, disk_buffer             ; DI aponta para início do root dir

    ; --- Procura entrada do arquivo ---
    pop ax                          ; Recupera ponteiro do nome convertido
    call disk_get_root_entry        ; Procura entrada (retorna DI se achou)
    jc remove_file_failure          ; Se não achou → erro

    ; --- Entrada encontrada ---
    mov ax, word [es:di+26]         ; Cluster inicial do arquivo
    mov word [remove_file_cluster], ax

    mov byte [di], 0E5h             ; Marca entrada como apagada (0xE5)

    inc di
    mov cx, 0
remove_file_clean_loop:             ; Zera o restante da entrada (31 bytes)
    mov byte [di], 0
    inc di
    inc cx
    cmp cx, 31
    jl remove_file_clean_loop

    ; --- Grava root dir atualizado ---
    call disk_write_root_dir

    ; --- Lê FAT ---
    call disk_read_fat
    mov di, disk_buffer             ; DI aponta para FAT em memória

; --------------------------------------------------------------------------
; Libera clusters ocupados pelo arquivo na FAT
; --------------------------------------------------------------------------
remove_file_more_clusters:
    mov ax, [remove_file_cluster]   ; Cluster atual
    cmp ax, 0
    je remove_file_nothing_to_do    ; Se zero → arquivo vazio

    ; --- Calcula posição na FAT ---
    mov bx, 3
    mul bx                          ; AX = cluster * 3
    mov bx, 2
    div bx                          ; AX = offset, DX = cluster mod 2
    mov si, disk_buffer
    add si, ax
    mov ax, [ds:si]                 ; Lê 2 bytes da FAT

    ; --- Verifica se cluster é par ou ímpar ---
    or dx, dx
    jz remove_file_even

; --- Cluster ímpar ---
remove_file_odd:
    push ax
    and ax, 000Fh                   ; Zera 12 bits do cluster na FAT
    mov [ds:si], ax
    pop ax
    shr ax, 4                       ; Próximo cluster = bits altos
    jmp remove_file_calculate_cluster_cont

; --- Cluster par ---
remove_file_even:
    push ax
    and ax, 0F000h                  ; Zera 12 bits do cluster na FAT
    mov [ds:si], ax
    pop ax
    and ax, 0FFFh                   ; Próximo cluster = bits baixos

; --- Atualiza cluster e continua ---
remove_file_calculate_cluster_cont:
    mov [remove_file_cluster], ax

    cmp ax, 0FF8h                   ; Fim da cadeia?
    jae remove_file_end
    jmp remove_file_more_clusters

; --------------------------------------------------------------------------
; Finaliza remoção
; --------------------------------------------------------------------------
remove_file_end:
    call disk_write_fat             ; Grava FAT atualizada
    jc remove_file_failure

remove_file_nothing_to_do:
    popa
    clc                             ; Carry = 0 → sucesso
    ret

remove_file_failure:
    popa
    stc                             ; Carry = 1 → falha
    ret

; --------------------------------------------------------------------------
; create_file -- Cria um novo arquivo de 0 bytes no disquete (FAT12)
; --------------------------------------------------------------------------
; Objetivo:
;   Criar uma nova entrada de arquivo no diretório raiz do disquete,
;   com tamanho zero e sem alocação de clusters.
;
; Contrato:
;   Entrada:
;     AX = ponteiro para nome do arquivo (ASCIIZ)
;   Saída:
;     Carry Flag = 0 → sucesso
;     Carry Flag = 1 → falha (arquivo já existe ou sem espaço)
;
; Preservação:
;   Usa PUSHA/POPA para preservar todos os registradores.
;
; Observações:
;   - O nome é convertido para maiúsculas e formato FAT 8.3.
;   - O diretório raiz pode ter até 224 entradas.
;   - Se o arquivo já existir, a função falha.
;   - Campos de data/hora são preenchidos com valores fictícios (dummy).
; --------------------------------------------------------------------------

create_file:
    clc                             ; Assume sucesso inicial

    ; --- Conversão do nome ---
    call string_uppercase           ; Converte string para maiúsculas
    call int_filename_convert       ; Converte para formato FAT12 8.3
    pusha                           ; Salva registradores
    push ax                         ; Guarda ponteiro do nome convertido

    ; --- Verifica se já existe ---
    call file_exists                ; Verifica se arquivo já existe
    jnc create_file_exists_error    ; CF=0 → já existe → erro

    ; --- Root dir já está em disk_buffer (carregado por file_exists) ---
    mov di, disk_buffer             ; DI aponta para início do root dir

    ; --- Procura entrada livre no root dir ---
    mov cx, 224                     ; Número máximo de entradas no root
create_file_next_entry:
    mov al, [di]
    cmp al, 0                       ; Entrada livre (0x00)?
    je create_file_found_free_entry
    cmp al, 0E5h                    ; Entrada apagada (0xE5)?
    je create_file_found_free_entry
    add di, 32                      ; Avança para próxima entrada (32 bytes)
    loop create_file_next_entry

; --------------------------------------------------------------------------
; Nenhuma entrada livre encontrada OU arquivo já existia
; --------------------------------------------------------------------------
create_file_exists_error:
    pop ax                          ; Restaura ponteiro do nome
    popa
    stc                             ; Carry=1 → falha
    ret

; --------------------------------------------------------------------------
; Entrada livre encontrada → cria arquivo
; --------------------------------------------------------------------------
create_file_found_free_entry:
    pop si                          ; Recupera ponteiro do nome convertido
    mov cx, 11
    rep movsb                       ; Copia nome 8.3 para entrada do root

    sub di, 11                      ; Volta DI para início da entrada

    ; --- Preenche campos da entrada ---
    mov byte [di+11], 0             ; Atributos (arquivo normal)
    mov byte [di+12], 0             ; Reservado
    mov byte [di+13], 0             ; Reservado
    mov byte [di+14], 0C6h          ; Hora de criação (dummy)
    mov byte [di+15], 07Eh          ; Hora de criação (dummy)
    mov byte [di+16], 0             ; Data de criação
    mov byte [di+17], 0             ; Data de criação
    mov byte [di+18], 0             ; Último acesso
    mov byte [di+19], 0             ; Último acesso
    mov byte [di+20], 0             ; FAT12 ignora
    mov byte [di+21], 0             ; FAT12 ignora
    mov byte [di+22], 0C6h          ; Hora última escrita (dummy)
    mov byte [di+23], 07Eh          ; Hora última escrita (dummy)
    mov byte [di+24], 0             ; Data última escrita
    mov byte [di+25], 0             ; Data última escrita
    mov byte [di+26], 0             ; Cluster inicial (0 = nenhum)
    mov byte [di+27], 0             ; Cluster inicial
    mov byte [di+28], 0             ; Tamanho do arquivo (0 bytes)
    mov byte [di+29], 0
    mov byte [di+30], 0
    mov byte [di+31], 0

    ; --- Grava root dir atualizado ---
    call disk_write_root_dir
    jc create_file_failure          ; Se falha na escrita → erro

    popa
    clc                             ; Carry=0 → sucesso
    ret

; --------------------------------------------------------------------------
; Falha na gravação do root dir
; --------------------------------------------------------------------------
create_file_failure:
    popa
    stc                             ; Carry=1 → falha
    ret
	
	
; --------------------------------------------------------------------------
; create_directory -- Cria um novo subdiretório no diretório atual (FAT12)
; --------------------------------------------------------------------------
; IN: AX = ponteiro para nome do diretório (ASCIIZ)
; OUT: Carry Flag = 0 (sucesso), 1 (falha)
; --------------------------------------------------------------------------

new_dir_buffer equ 0x7000          ; Buffer separado para diretórios

create_directory:
    clc                             ; Assume sucesso inicial

    call string_uppercase           ; Converte nome para maiúsculas
    call int_dir_convert            ; Converte para formato FAT 8.3
    pusha
    push ax                         ; Guarda ponteiro do nome convertido

    ; --- Verifica se já existe ---
    call file_exists
    jnc create_directory_exists_error ; CF=0 → já existe → erro

    ; --- Carrega root dir ---
    call disk_read_root_dir
    jc create_directory_failure

    ; --- Procura entrada livre no root dir ---
    mov di, disk_buffer
    mov cx, 224
create_directory_next_entry:
    mov al, [di]
    cmp al, 0
    je create_directory_found_free_entry
    cmp al, 0xE5
    je create_directory_found_free_entry
    add di, 32
    loop create_directory_next_entry

create_directory_exists_error:
    pop ax
    popa
    stc
    ret

create_directory_found_free_entry:
    pop si                          ; SI = ponteiro para nome convertido
    mov cx, 11
    rep movsb                       ; Copia nome 8.3 para entrada

    sub di, 11                      ; Volta DI para início da entrada

    ; --- Aloca cluster para o diretório ---
    call fat_allocate_cluster
    jc create_directory_failure

    mov bx, ax                      ; BX = cluster alocado

    ; --- Marca cluster como usado na FAT ---
    mov ax, 0x0FFF                  ; fim de arquivo
    call fat_write_entry            ; grava na FAT: BX → AX

    ; --- Preenche entrada de diretório ---
    mov byte [di+11], 0x10          ; Atributo: diretório
    mov byte [di+12], 0             ; Reservado
    mov byte [di+13], 0             ; Reservado
    mov byte [di+14], 0xC6          ; Hora (dummy)
    mov byte [di+15], 0x7E
    mov byte [di+16], 0             ; Data (dummy)
    mov byte [di+17], 0
    mov byte [di+18], 0             ; Último acesso
    mov byte [di+19], 0
    mov byte [di+20], 0             ; FAT12 ignora
    mov byte [di+21], 0
    mov byte [di+22], 0xC6          ; Hora última escrita
    mov byte [di+23], 0x7E
    mov byte [di+24], 0             ; Data última escrita
    mov byte [di+25], 0
    mov [di+26], bx                 ; Cluster inicial (2 bytes)
    mov dword [di+28], 0            ; Tamanho = 0

    ; --- Inicializa cluster com "." e ".." ---
    call disk_clear_cluster        ; Zera cluster

    ; Carrega cluster alocado em new_dir_buffer
    mov ax, new_dir_buffer
    mov es, ax
    call disk_load_cluster

    ; Entrada "."
    mov di, new_dir_buffer
    mov byte [di], '.'             ; Nome
    mov byte [di+1], ' '
    mov byte [di+2], ' '
    mov byte [di+3], ' '
    mov byte [di+4], ' '
    mov byte [di+5], ' '
    mov byte [di+6], ' '
    mov byte [di+7], ' '
    mov byte [di+8], ' '
    mov byte [di+9], ' '
    mov byte [di+10], ' '
    mov byte [di+11], 0x10         ; Atributo: diretório
    mov word [di+26], bx           ; Cluster = próprio

    ; Entrada ".."
    add di, 32
    mov byte [di], '.'             ; Nome
    mov byte [di+1], '.'           ; Nome
    mov byte [di+2], ' '
    mov byte [di+3], ' '
    mov byte [di+4], ' '
    mov byte [di+5], ' '
    mov byte [di+6], ' '
    mov byte [di+7], ' '
    mov byte [di+8], ' '
    mov byte [di+9], ' '
    mov byte [di+10], ' '
    mov byte [di+11], 0x10         ; Atributo: diretório
    mov word [di+26], 0            ; Cluster do pai (0 = root)

    ; --- Grava cluster do diretório ---
    mov ax, new_dir_buffer
    mov es, ax
    call disk_write_cluster
    jc create_directory_failure

    ; --- Grava root dir atualizado ---
    call disk_write_root_dir
    jc create_directory_failure

    ; --- Recarrega root dir para manter buffer atualizado ---
    call disk_read_root_dir

    popa
    clc
    ret

create_directory_failure:
    popa
    stc
    ret


remove_directory:
    pusha                           ; Salva todos os registradores

    ; --- Conversão do nome ---
    call string_uppercase           ; Converte string para maiúsculas
    call int_dir_convert       ; Converte para formato FAT12 8.3
    push ax                         ; Guarda ponteiro do nome convertido

    clc                             ; Assume sucesso inicial

    ; --- Lê diretório raiz ---
    call disk_read_root_dir         ; Carrega root dir em disk_buffer
    mov di, disk_buffer             ; DI aponta para início do root dir

    ; --- Procura entrada do arquivo ---
    pop ax                          ; Recupera ponteiro do nome convertido
    call disk_get_root_entry        ; Procura entrada (retorna DI se achou)
    jc remove_dir_failure          ; Se não achou → erro

    ; --- Entrada encontrada ---
    mov ax, word [es:di+26]         ; Cluster inicial do arquivo
    mov word [remove_dir_cluster], ax

    mov byte [di], 0E5h             ; Marca entrada como apagada (0xE5)

    inc di
    mov cx, 0
remove_dir_clean_loop:             ; Zera o restante da entrada (31 bytes)
    mov byte [di], 0
    inc di
    inc cx
    cmp cx, 31
    jl remove_dir_clean_loop

    ; --- Grava root dir atualizado ---
    call disk_write_root_dir

    ; --- Lê FAT ---
    call disk_read_fat
    mov di, disk_buffer             ; DI aponta para FAT em memória

; --------------------------------------------------------------------------
; Libera clusters ocupados pelo arquivo na FAT
; --------------------------------------------------------------------------
remove_dir_more_clusters:
    mov ax, [remove_dir_cluster]   ; Cluster atual
    cmp ax, 0
    je remove_dir_nothing_to_do    ; Se zero → arquivo vazio

    ; --- Calcula posição na FAT ---
    mov bx, 3
    mul bx                          ; AX = cluster * 3
    mov bx, 2
    div bx                          ; AX = offset, DX = cluster mod 2
    mov si, disk_buffer
    add si, ax
    mov ax, [ds:si]                 ; Lê 2 bytes da FAT

    ; --- Verifica se cluster é par ou ímpar ---
    or dx, dx
    jz remove_dir_even

; --- Cluster ímpar ---
remove_dir_odd:
    push ax
    and ax, 000Fh                   ; Zera 12 bits do cluster na FAT
    mov [ds:si], ax
    pop ax
    shr ax, 4                       ; Próximo cluster = bits altos
    jmp remove_dir_calculate_cluster_cont

; --- Cluster par ---
remove_dir_even:
    push ax
    and ax, 0F000h                  ; Zera 12 bits do cluster na FAT
    mov [ds:si], ax
    pop ax
    and ax, 0FFFh                   ; Próximo cluster = bits baixos

; --- Atualiza cluster e continua ---
remove_dir_calculate_cluster_cont:
    mov [remove_dir_cluster], ax

    cmp ax, 0FF8h                   ; Fim da cadeia?
    jae remove_dir_end
    jmp remove_dir_more_clusters

; --------------------------------------------------------------------------
; Finaliza remoção
; --------------------------------------------------------------------------
remove_dir_end:
    call disk_write_fat             ; Grava FAT atualizada
    jc remove_dir_failure

remove_dir_nothing_to_do:
    popa
    clc                             ; Carry = 0 → sucesso
    ret

remove_dir_failure:
    popa
    stc                             ; Carry = 1 → falha
    ret
; ==================================================================
; DISK.ASM - Rotinas de acesso a disco (FAT12, disquete)
; ==================================================================

; ------------------------------------------------------------------
; load_file -- Load file into RAM
; IN: AX = ponteiro para nome do arquivo
;     CX = endereço linear de destino na RAM
; OUT: BX = tamanho LOW WORD do arquivo (em bytes)
;      Carry Flag setada em caso de erro/arquivo não encontrado
; Obs: Não usa PUSHA/POPA, salvamento manual de registradores
; ------------------------------------------------------------------
load_file:
    ; --- Salvamento de registradores usados ---
    push ax                 ; salva ponteiro do nome
    push cx                 ; salva endereço linear destino
    push dx                 ; usado em divisões e cálculos
    push si                 ; usado como ponteiro
    push di                 ; usado como ponteiro
    push bp                 ; usado em cálculos temporários
    push ds                 ; segmento de dados
    push es                 ; segmento extra

    ; --- Conversão do nome ---
    mov si, ax              ; SI = ponteiro para nome
    call string_uppercase   ; converte string para maiúsculas
    mov ax, si              ; AX = ponteiro para nome uppercase
    call int_filename_convert ; converte para formato FAT 8.3
    jc load_file_load_fail_exit ; se Carry=1 → nome inválido

    mov word [load_file_filename_loc], ax   ; guarda nome convertido
    mov word [load_file_load_address_linear], cx ; guarda endereço linear destino

    mov eax, 0              ; zera EAX (defensivo)

    ; --- Reset do disquete ---
    call floppy_reset  ; reseta controladora
    jnc load_file_floppy_ok ; se sucesso, continua
    stc                     ; se falha, seta Carry
    jmp load_file_load_fail_exit

load_file_floppy_ok:
    ; --- Lê diretório raiz ---
    call disk_read_root_dir ; carrega root dir em buffer
    jc load_file_load_fail_exit ; erro → sai

    ; --- Procura entrada do arquivo ---
    mov ax, word [load_file_filename_loc] ; nome 8.3
    mov di, disk_buffer     ; DI = início do root dir
    call disk_get_root_entry ; procura entrada
    jc load_file_load_fail_exit ; não achou → erro

    ; --- Entrada encontrada ---
    mov ax, [di+28]         ; tamanho low word
    mov dx, [di+30]         ; tamanho high word
    mov word [load_file_file_size], ax
    mov word [load_file_file_size+2], dx

    or dx, ax               ; verifica se tamanho = 0
    jz load_file_end_ok     ; se zero, termina com sucesso

    mov ax, [di+26]         ; cluster inicial
    mov word [load_file_cluster], ax

    ; --- Lê FAT ---
    call disk_read_fat
    jc load_file_load_fail_exit

    ; --- Calcula ES:BX a partir do endereço linear ---
    mov ax, word [load_file_load_address_linear] ; linear base
    mov dx, 0
    mov si, 16              ; divisor = 16
    div si                  ; AX=segmento, DX=offset
    mov es, ax              ; ES = segmento
    mov bx, dx              ; BX = offset

; --- Loop de leitura de setores ---
load_file_load_file_sector:
    mov ax, word [load_file_cluster] ; cluster atual
    add ax, 31              ; converte cluster em LBA (dados começam no setor 31)
    call lba_to_chs ; converte LBA → CHS

    mov ah, 0x02            ; função INT13h: ler setor
    mov al, 0x01            ; 1 setor

    mov si, 3               ; 3 tentativas
load_file_load_retry:
    stc
    int 13h                 ; lê setor para ES:BX
    jnc load_file_calculate_next_cluster ; se sucesso, continua

    call floppy_reset  ; reset em caso de erro
    dec si
    test si, si
    jnz load_file_load_retry ; tenta de novo até 3 vezes
    jmp load_file_load_fail_exit ; falhou → erro

; --- Calcula próximo cluster na FAT12 ---
load_file_calculate_next_cluster:
    mov ax, word [load_file_cluster] ; cluster atual
    mov bp, 3
    mul bp                  ; AX = cluster*3
    mov bp, 2
    div bp                  ; AX = (3*cluster)/2, DX = resto
    mov si, disk_buffer     ; SI = FAT
    add si, ax              ; SI aponta para entrada
    mov ax, word [ds:si]    ; lê 2 bytes da FAT

    cmp dx, 0
    je load_file_even
load_file_odd:
    shr ax, 4               ; cluster ímpar → pega 12 bits altos
    jmp load_file_get_cluster_cont
load_file_even:
    and ax, 0x0FFF          ; cluster par → pega 12 bits baixos

load_file_get_cluster_cont:
    mov word [load_file_cluster], ax ; atualiza cluster

    cmp ax, 0x0FF8
    jae load_file_end_ok    ; >=0xFF8 → fim da cadeia

    ; --- Avança destino em 512 bytes ---
    add bx, 512
    jnc load_file_no_segment_inc
    mov ax, es
    add ax, 0x20            ; 512/16 = 32 parágrafos
    mov es, ax
load_file_no_segment_inc:
    jmp load_file_load_file_sector ; continua leitura

; --- Sucesso ---
load_file_end_ok:
    mov bx, word [load_file_file_size] ; retorna tamanho LOW WORD
    clc                     ; Carry=0 → sucesso
    jmp load_file_exit

; --- Falha ---
load_file_load_fail_exit:
    mov bx, 0               ; tamanho = 0
    stc                     ; Carry=1 → erro

; --- Restauração ---
load_file_exit:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret                     ; retorna com BX=tamanho, CF=status
