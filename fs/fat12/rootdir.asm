; ==================================================================
; src/fs/fat12/rootdir.asm - Leitura, Escrita e Busca no Root Dir
; (Lógica Original Restaurada)
; ==================================================================

; --------------------------------------------------------------------------
; disk_read_fat -- Ler a FAT do disquete para a RAM (disk_buffer)
; --------------------------------------------------------------------------
; Objetivo:
;   Carregar a FAT (File Allocation Table) do disquete para a memória,
;   dentro do buffer `disk_buffer`, para que o sistema possa navegar
;   pelas cadeias de clusters dos arquivos.
;
; Contrato:
;   Entrada:
;     Nenhuma (usa parâmetros fixos do FAT12 em disquete de 1,44MB)
;   Saída:
;     CF = 0 se sucesso (FAT carregada em disk_buffer)
;     CF = 1 se falha (erro de leitura)
;
; Contexto FAT12:
;   - O setor lógico 0 contém o Boot Sector.
;   - A FAT começa no setor lógico 1.
;   - Cada FAT ocupa 9 setores em disquetes de 1,44MB.
;   - Normalmente existem 2 cópias da FAT, mas aqui lemos apenas a primeira.
; --------------------------------------------------------------------------
disk_read_fat:
    pusha                           ; Salva todos os registradores

    mov ax, 1                       ; FAT começa no setor lógico 1 (logo após o boot sector)
    call lba_to_chs        ; Converte LBA (1) para CHS (Cylinder-Head-Sector)
                                    ; Necessário porque a BIOS INT 13h usa CHS

    ; --------------------------------------------------------------
    ; Configurar ES:BX para apontar para o buffer de destino
    ; --------------------------------------------------------------
    mov bx, ds                      ; BX = segmento atual (DS)
    mov es, bx                      ; ES = DS (segmento de dados)
    mov bx, disk_buffer             ; BX = offset do buffer onde FAT será armazenada

    ; --------------------------------------------------------------
    ; Preparar parâmetros para INT 13h
    ; --------------------------------------------------------------
    mov ah, 2                       ; Função 02h: "Read Sectors"
    mov al, 9                       ; Ler 9 setores (tamanho da FAT em disquete 1,44MB)

    pusha                           ; Salva contexto antes do loop de tentativas


; --------------------------------------------------------------------------
; Loop de leitura com tratamento de erro
; --------------------------------------------------------------------------
disk_read_fat_loop:
    popa                            ; Restaura registradores
    pusha                           ; Salva novamente (mantém estado consistente)

    stc                             ; Define Carry Flag antes da chamada
                                    ; Algumas BIOS só limpam CF em caso de sucesso
    int 13h                         ; Chama BIOS para ler setores da FAT

    jnc disk_read_fat_done          ; Se CF=0 (sem erro), leitura bem-sucedida

    ; --------------------------------------------------------------
    ; Caso ocorra erro de leitura
    ; --------------------------------------------------------------
    call floppy_reset          ; Tenta resetar o controlador de disquete
    jnc disk_read_fat_loop          ; Se reset bem-sucedido, tenta novamente

    ; Se reset também falhar, aborta
    popa
    jmp disk_read_fat_failure       ; Erro fatal: não conseguiu ler FAT


; --------------------------------------------------------------------------
; Sucesso na leitura
; --------------------------------------------------------------------------
disk_read_fat_done:
    popa                            ; Restaura registradores do loop de retry
    popa                            ; Restaura registradores do início da função
    clc                             ; CF=0 (sucesso)
    ret


; --------------------------------------------------------------------------
; Falha definitiva
; --------------------------------------------------------------------------
disk_read_fat_failure:
    popa                            ; Restaura registradores
    stc                             ; CF=1 (falha)
    ret

; --------------------------------------------------------------------------
; disk_write_fat -- Gravar a FAT da RAM (disk_buffer) de volta no disquete
; --------------------------------------------------------------------------
; Objetivo:
;   Escrever os 9 setores da FAT (File Allocation Table) que estão
;   armazenados em memória (disk_buffer) de volta para o disquete.
;
; Contrato:
;   Entrada:
;     - A FAT já deve estar carregada e modificada em disk_buffer.
;   Saída:
;     - CF = 0 se sucesso (gravação concluída)
;     - CF = 1 se falha (erro após 3 tentativas)
;
; Contexto FAT12:
;   - O setor lógico 0 = Boot Sector.
;   - A FAT começa no setor lógico 1.
;   - Cada FAT ocupa 9 setores em disquetes de 1,44MB.
;   - Normalmente existem 2 cópias da FAT, mas aqui só gravamos a primeira.
; --------------------------------------------------------------------------
disk_write_fat:
    pusha                           ; Salva todos os registradores

    mov ax, 1                       ; FAT começa no setor lógico 1
    call lba_to_chs        ; Converte LBA=1 para CHS (Cylinder-Head-Sector)
                                    ; Necessário porque a BIOS INT 13h usa CHS

    ; --------------------------------------------------------------
    ; Configurar ES:BX para apontar para o buffer de origem
    ; --------------------------------------------------------------
    mov bx, ds                      ; BX = segmento atual (DS)
    mov es, bx                      ; ES = DS (segmento de dados)
    mov bx, disk_buffer             ; BX = offset do buffer onde está a FAT

    ; --------------------------------------------------------------
    ; Preparar parâmetros para INT 13h
    ; --------------------------------------------------------------
    mov ah, 3                       ; Função 03h: "Write Sectors"
    mov al, 9                       ; Escrever 9 setores (tamanho da FAT)

    mov di, 3                       ; Contador de tentativas (3 chances)

; --------------------------------------------------------------------------
; Loop de escrita com até 3 tentativas
; --------------------------------------------------------------------------
disk_write_fat_retry:
    stc                             ; Define Carry Flag antes da chamada
                                    ; Algumas BIOS só limpam CF em caso de sucesso
    int 13h                         ; Chama BIOS para escrever setores

    jnc disk_write_fat_done         ; Se CF=0 (sem erro), gravação bem-sucedida

    ; --------------------------------------------------------------
    ; Caso ocorra erro de escrita
    ; --------------------------------------------------------------
    call floppy_reset          ; Tenta resetar o controlador de disquete
    dec di                          ; Decrementa contador de tentativas
    test di, di                     ; Ainda restam tentativas?
    jnz disk_write_fat_retry        ; Se sim, tenta novamente

    ; Se falhou 3 vezes, aborta
    jmp disk_write_fat_write_failure


; --------------------------------------------------------------------------
; Sucesso na escrita
; --------------------------------------------------------------------------
disk_write_fat_done:
    popa                            ; Restaura registradores
    clc                             ; CF=0 (sucesso)
    ret


; --------------------------------------------------------------------------
; Falha definitiva
; --------------------------------------------------------------------------
disk_write_fat_write_failure:
    popa                            ; Restaura registradores
    stc                             ; CF=1 (falha)
    ret

; --------------------------------------------------------------------------
; disk_read_root_dir -- Ler o diretório raiz do disquete para a RAM
; --------------------------------------------------------------------------
; Objetivo:
;   Carregar o conteúdo do diretório raiz (root directory) do disquete
;   para a memória, dentro do buffer `disk_buffer`.
;
; Contrato:
;   Entrada:
;     Nenhuma (parâmetros fixos para disquete FAT12 de 1,44MB).
;   Saída:
;     - Se sucesso: `disk_buffer` conterá as 224 entradas do diretório raiz.
;     - CF = 0 (carry clear).
;     - Se falha: CF = 1 (carry set).
;
; Contexto FAT12:
;   - Setor 0: Boot Sector.
;   - Setores 1–9: FAT1.
;   - Setores 10–18: FAT2.
;   - Setor 19: início do diretório raiz.
;   - O diretório raiz ocupa 14 setores (224 entradas × 32 bytes = 7168 bytes).
; --------------------------------------------------------------------------
disk_read_root_dir:
    pusha                           ; Salva todos os registradores

    mov ax, 19                      ; O diretório raiz começa no setor lógico 19
    call lba_to_chs         ; Converte LBA=19 para CHS (Cylinder-Head-Sector)
                                    ; Necessário porque a BIOS INT 13h usa CHS

    ; --------------------------------------------------------------
    ; Configurar ES:BX para apontar para o buffer de destino
    ; --------------------------------------------------------------
    mov bx, ds                      ; BX = segmento atual (DS)
    mov es, bx                      ; ES = DS (segmento de dados)
    mov bx, disk_buffer             ; BX = offset do buffer onde será armazenado

    ; --------------------------------------------------------------
    ; Preparar parâmetros para INT 13h
    ; --------------------------------------------------------------
    mov ah, 2                       ; Função 02h: "Read Sectors"
    mov al, 14                      ; Ler 14 setores (tamanho do root dir)

    pusha                           ; Salva contexto antes do loop de retry


; --------------------------------------------------------------------------
; Loop de leitura com tratamento de erro
; --------------------------------------------------------------------------
disk_read_root_dir_loop:
    popa                            ; Restaura registradores
    pusha                           ; Salva novamente (mantém estado consistente)

    stc                             ; Define Carry Flag antes da chamada
                                    ; Algumas BIOS só limpam CF em caso de sucesso
    int 13h                         ; Chama BIOS para ler setores

    jnc disk_read_root_dir_finished ; Se CF=0 (sem erro), leitura bem-sucedida

    ; --------------------------------------------------------------
    ; Caso ocorra erro de leitura
    ; --------------------------------------------------------------
    call floppy_reset          ; Tenta resetar o controlador de disquete
    jnc disk_read_root_dir_loop     ; Se reset bem-sucedido, tenta novamente

    ; Se reset também falhar, aborta
    popa
    jmp disk_read_root_dir_failure  ; Erro fatal: não conseguiu ler root dir


; --------------------------------------------------------------------------
; Sucesso na leitura
; --------------------------------------------------------------------------
disk_read_root_dir_finished:
    popa                            ; Restaura registradores do loop de retry
    popa                            ; Restaura registradores do início da função
    clc                             ; CF=0 (sucesso)
    ret


; --------------------------------------------------------------------------
; Falha definitiva
; --------------------------------------------------------------------------
disk_read_root_dir_failure:
    popa                            ; Restaura registradores
    stc                             ; CF=1 (falha)
    ret

; --------------------------------------------------------------------------
; disk_write_root_dir -- Gravar o diretório raiz da RAM (disk_buffer) no disquete
; --------------------------------------------------------------------------
; Objetivo:
;   Escrever os 14 setores do diretório raiz (root directory) que estão
;   armazenados em memória (disk_buffer) de volta para o disquete.
;
; Contrato:
;   Entrada:
;     - O diretório raiz já deve estar carregado e modificado em disk_buffer.
;   Saída:
;     - CF = 0 se sucesso (gravação concluída)
;     - CF = 1 se falha (erro após 3 tentativas)
;
; Contexto FAT12:
;   - Setor 0: Boot Sector.
;   - Setores 1–9: FAT1.
;   - Setores 10–18: FAT2.
;   - Setor 19: início do diretório raiz.
;   - O diretório raiz ocupa 14 setores (224 entradas × 32 bytes = 7168 bytes).
; --------------------------------------------------------------------------
disk_write_root_dir:
    pusha                           ; Salva todos os registradores

    mov ax, 19                      ; O diretório raiz começa no setor lógico 19
    call lba_to_chs         ; Converte LBA=19 para CHS (Cylinder-Head-Sector)
                                    ; Necessário porque a BIOS INT 13h usa CHS

    ; --------------------------------------------------------------
    ; Configurar ES:BX para apontar para o buffer de origem
    ; --------------------------------------------------------------
    mov bx, ds                      ; BX = segmento atual (DS)
    mov es, bx                      ; ES = DS (segmento de dados)
    mov bx, disk_buffer             ; BX = offset do buffer onde está o root dir

    ; --------------------------------------------------------------
    ; Preparar parâmetros para INT 13h
    ; --------------------------------------------------------------
    mov ah, 3                       ; Função 03h: "Write Sectors"
    mov al, 14                      ; Escrever 14 setores (tamanho do root dir)

    mov di, 3                       ; Contador de tentativas (3 chances)

; --------------------------------------------------------------------------
; Loop de escrita com até 3 tentativas
; --------------------------------------------------------------------------
disk_write_root_dir_retry:
    stc                             ; Define Carry Flag antes da chamada
                                    ; Algumas BIOS só limpam CF em caso de sucesso
    int 13h                         ; Chama BIOS para escrever setores

    jnc disk_write_root_dir_done    ; Se CF=0 (sem erro), gravação bem-sucedida

    ; --------------------------------------------------------------
    ; Caso ocorra erro de escrita
    ; --------------------------------------------------------------
    call floppy_reset          ; Tenta resetar o controlador de disquete
    dec di                          ; Decrementa contador de tentativas
    test di, di                     ; Ainda restam tentativas?
    jnz disk_write_root_dir_retry   ; Se sim, tenta novamente

    ; Se falhou 3 vezes, aborta
    jmp disk_write_root_dir_write_failure


; --------------------------------------------------------------------------
; Sucesso na escrita
; --------------------------------------------------------------------------
disk_write_root_dir_done:
    popa                            ; Restaura registradores
    clc                             ; CF=0 (sucesso)
    ret


; --------------------------------------------------------------------------
; Falha definitiva
; --------------------------------------------------------------------------
disk_write_root_dir_write_failure:
    popa                            ; Restaura registradores
    stc                             ; CF=1 (falha)
    ret
	

; --------------------------------------------------------------------------
; disk_get_root_entry
; --------------------------------------------------------------------------
; Objetivo:
;   Procurar no diretório raiz (já carregado em RAM no disk_buffer)
;   a entrada correspondente a um arquivo específico no formato FAT12 8.3.
;
; Contrato:
;   Entrada:
;     AX = ponteiro para string no formato FAT12 (8.3, já convertido)
;     DI = buffer base (assume disk_buffer como área onde o root dir foi lido)
;   Saída:
;     DI = endereço dentro do disk_buffer onde começa a entrada do arquivo
;     CF = 0 se encontrado
;     CF = 1 se não encontrado
;
; Contexto FAT12:
;   - O diretório raiz de um disquete FAT12 tem 224 entradas fixas.
;   - Cada entrada ocupa 32 bytes.
;   - O nome do arquivo ocupa os 11 primeiros bytes (8 nome + 3 extensão).
;   - Portanto, para cada entrada, basta comparar 11 bytes com o nome-alvo.
; --------------------------------------------------------------------------
disk_get_root_entry: pusha                               ; Salva todos os registradores

    mov word [disk_get_root_entry_filename_var], ax
                                        ; Salva o ponteiro para o nome-alvo
                                        ; (string 8.3 já convertida)

    mov cx, 224                         ; Número máximo de entradas no root dir
    mov bp, 0                           ; BP = offset dentro do disk_buffer
                                        ; (0 = primeira entrada)

; --------------------------------------------------------------------------
; Loop principal: percorre todas as entradas do diretório raiz
; --------------------------------------------------------------------------
disk_get_root_entry_next:
    ; SI = ponteiro para string alvo (nome 8.3)
    mov si, word [disk_get_root_entry_filename_var]

    ; DI = ponteiro para a entrada atual no disk_buffer
    mov di, disk_buffer
    add di, bp                          ; DI = início da entrada atual

    ; Comparar 11 bytes (nome + extensão)
    push cx                             ; Salva contador externo (entradas restantes)
    mov cx, 11                          ; Precisamos comparar 11 bytes
    repe cmpsb                          ; Compara [SI] com [ES:DI], avança ambos
                                        ; REP repete até CX=0 ou diferença encontrada
                                        ; ZF=1 se todos os bytes foram iguais
    pop cx                              ; Restaura contador externo

    je disk_get_root_entry_found        ; Se ZF=1, nome encontrado

    ; Caso não tenha batido:
    add bp, 32                          ; Avança para próxima entrada (32 bytes)
    loop disk_get_root_entry_next       ; Decrementa CX (entradas restantes)
                                        ; Continua se ainda houver entradas

    ; Se saiu do loop, não encontrou
    popa
    stc                                 ; CF=1 (não encontrado)
    ret

; --------------------------------------------------------------------------
; Caso encontrado
; --------------------------------------------------------------------------
disk_get_root_entry_found:
    ; Observação:
    ; Após o REP CMPSB, DI foi incrementado em 11 bytes
    ; (pois comparou 11 caracteres do nome).
    ; Portanto, DI aponta 11 bytes após o início da entrada.
    ; Precisamos ajustar para voltar ao início da entrada.

    mov word [disk_get_root_entry_tmp_var], di
                                        ; Salva DI atual
    sub word [disk_get_root_entry_tmp_var], 11
                                        ; Ajusta para o início da entrada

    popa                                ; Restaura registradores
    mov di, [disk_get_root_entry_tmp_var]
                                        ; DI = início da entrada encontrada
    clc                                 ; CF=0 (sucesso)
    ret

; --------------------------------------------------------------------------
; Variáveis globais auxiliares
; --------------------------------------------------------------------------
disk_get_root_entry_filename_var dw 0   ; Ponteiro para nome alvo (8.3)
disk_get_root_entry_tmp_var      dw 0   ; Armazena endereço temporário da entrada

