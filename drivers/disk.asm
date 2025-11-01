; ==============================================================================
; Arquivo:    disk.asm
; Caminho:    src/drivers/disk.asm
; Projeto:    Sistema Operacional (FAT12)
; Autor:      Felipe Andrian Peixoto
; ==============================================================================
; Descrição:
;   Este módulo implementa rotinas de baixo nível para acesso a disco via BIOS,
;   com suporte ao sistema de arquivos FAT12. Ele fornece funções para:
;
;   - Resetar o controlador de disquete (INT 0x13, função 0x00)
;   - Converter endereçamento LBA para CHS (Cylinder-Head-Sector)
;   - Criar, remover e salvar arquivos no diretório raiz
;   - Manipular a FAT e clusters de dados
;
;   As funções aqui são utilizadas por camadas superiores do sistema para
;   realizar operações de leitura e escrita em disquetes de 1.44MB.
;
; Convenções:
;   - Todas as funções preservam registradores com PUSHA/POPA quando necessário.
;   - Os nomes dos arquivos seguem o padrão FAT 8.3 (ex: "README  TXT").
;   - O número da unidade (drive) é obtido de ebr_drive_number.
;
; Dependências:
;   - bpb_sectors_per_track, bpb_heads: parâmetros do BIOS Parameter Block
;   - disk_buffer: área de memória usada para leitura/escrita de setores
;   - ebr_drive_number: número da unidade (0 = A:, 1 = B:)
;
; Notas:
;   - Este código assume que o disquete está formatado corretamente em FAT12.
;   - Pode ser adaptado para HDs com ajustes no CHS e tamanho da FAT.
;
; ==============================================================================

; --------------------------------------------------------------------------
; floppy_reset -- Resetar o controlador de disquete
; --------------------------------------------------------------------------
; Objetivo:
;   Esta função reinicializa o controlador de disquete usando a BIOS.
;   É útil para recuperar o estado do drive após falhas de leitura ou escrita.
;
; Contexto técnico:
;   A BIOS oferece a função 0x00 da INT 0x13 para "Reset Disk System".
;   Isso limpa erros pendentes e reconfigura o controlador.
;
; Contrato:
;   Entrada: nenhuma (usa o número da unidade armazenado em ebr_drive_number)
;   Saída:
;     CF = 0 → sucesso
;     CF = 1 → falha
; --------------------------------------------------------------------------
floppy_reset:
    push ax                         ; Salva registradores usados
    push dx

    mov ah, 0x00                    ; AH = 0x00 → função "Reset Disk System"
    mov dl, [ebr_drive_number]      ; DL = número da unidade (0 = A:, 1 = B:)
    stc                             ; Define Carry Flag (CF) antes da chamada
    int 0x13                        ; Chama BIOS para resetar o drive

    pop dx                          ; Restaura registradores
    pop ax
    ret                             ; Retorna com CF indicando sucesso ou falha
	
	

; --------------------------------------------------------------------------
; lba_to_chs -- Converter setor lógico (LBA) em CHS (Cylinder-Head-Sector)
; --------------------------------------------------------------------------
; Objetivo:
;   Converte um número de setor lógico (LBA) em coordenadas físicas CHS,
;   que são exigidas pela BIOS para operações de leitura/escrita com INT 0x13.
;
; Contexto técnico:
;   - LBA (Logical Block Addressing) é uma forma linear de numerar setores.
;   - CHS (Cylinder-Head-Sector) é o formato físico usado pela BIOS.
;   - A BIOS espera:
;       CH = número do cilindro (bits 0–7)
;       CL = número do setor (bits 0–5) + bits altos do cilindro (bits 6–7)
;       DH = número da cabeça
;       DL = número da unidade (drive)
;
; Fórmulas usadas:
;   setor     = (LBA % setores_por_trilha) + 1
;   temp      = LBA / setores_por_trilha
;   cabeça    = temp % número_de_cabeças
;   cilindro  = temp / número_de_cabeças
;
; Contrato:
;   Entrada:
;     AX = número do setor lógico (LBA)
;   Saída:
;     CH, CL, DH, DL = coordenadas físicas para uso com INT 0x13
;   Preservação:
;     AX e BX restaurados ao final
; --------------------------------------------------------------------------
lba_to_chs:
    push bx                         ; Salva BX (usado como registrador auxiliar)
    push ax                         ; Salva AX (contém o LBA original)

    mov bx, ax                      ; BX = cópia do LBA para cálculos

    ; -------------------------------
    ; Etapa 1: Calcular o setor físico
    ; -------------------------------
    mov dx, 0                       ; Zera DX para divisão de 16 bits
    div word [bpb_sectors_per_track] ; Divide LBA por setores por trilha
                                     ; AX = número de trilhas completas
                                     ; DX = setor dentro da trilha
    add dl, 1                       ; BIOS espera setor começando em 1
    mov cl, dl                      ; CL = setor físico (bits 0–5)

    ; -------------------------------
    ; Etapa 2: Calcular cabeça e cilindro
    ; -------------------------------
    mov dx, 0
    div word [bpb_heads]           ; Divide trilhas completas por número de cabeças
                                   ; AX = número do cilindro
                                   ; DX = número da cabeça
    mov dh, dl                     ; DH = cabeça
    mov ch, al                     ; CH = parte baixa do cilindro (bits 0–7)

    ; -------------------------------
    ; Etapa 3: Inserir bits altos do cilindro em CL
    ; -------------------------------
    mov dl, ah                     ; Bits altos do cilindro estão em AH
    and dl, 0x03                   ; Isola apenas os bits 8 e 9
    shl dl, 6                      ; Move para posição correta (bits 6–7 de CL)
    or cl, dl                      ; Combina com setor já presente em CL

    ; -------------------------------
    ; Etapa 4: Restaurar valores e definir unidade
    ; -------------------------------
    pop ax                         ; Restaura AX original (LBA)
    mov dl, [ebr_drive_number]     ; DL = número da unidade (0 = A:, 1 = B:)
    pop bx                         ; Restaura BX original
    ret                            ; CH, CL, DH, DL prontos para uso com INT 0x13
	
	

; --------------------------------------------------------------------------
; disk_clear_cluster -- Zera o conteúdo de um cluster (FAT12)
; --------------------------------------------------------------------------
; Entrada: AX = número do cluster a ser zerado
; Saída: CF = 0 → sucesso, CF = 1 → falha
; Preserva: registradores com PUSHA/POPA
; --------------------------------------------------------------------------

disk_clear_cluster:
    pusha

    ; --- Converte cluster para LBA ---
    mov bx, ax              ; BX = cluster
    add bx, 31              ; Dados começam no setor 31
    mov ax, bx              ; AX = LBA
    call lba_to_chs         ; Converte LBA → CHS

    ; --- Prepara buffer com zeros ---
    mov di, disk_buffer
    mov cx, 512
    xor al, al
    rep stosb               ; Zera 512 bytes

    ; --- Escreve setor no disco ---
    mov ah, 0x03            ; INT 13h função: escrever setor
    mov al, 0x01            ; 1 setor
    mov si, 3               ; 3 tentativas

disk_clear_retry:
    stc
    int 13h
    jnc disk_clear_ok       ; Se sucesso, sai

    call floppy_reset
    dec si
    test si, si
    jnz disk_clear_retry

    stc                     ; Falhou
    popa
    ret

disk_clear_ok:
    clc
    popa
    ret
	

; --------------------------------------------------------------------------
; disk_write_cluster -- Grava o conteúdo de disk_buffer em um cluster (FAT12)
; --------------------------------------------------------------------------
; Entrada: AX = número do cluster a ser gravado
; Saída: CF = 0 → sucesso, CF = 1 → falha
; Preserva: registradores com PUSHA/POPA
; --------------------------------------------------------------------------

disk_write_cluster:
    pusha

    ; --- Converte cluster para LBA ---
    mov bx, ax              ; BX = cluster
    add bx, 31              ; Dados começam no setor 31
    mov ax, bx              ; AX = LBA
    call lba_to_chs         ; Converte LBA → CHS

    ; --- Prepara escrita ---
    mov ah, 0x03            ; INT 13h função: escrever setor
    mov al, 0x01            ; 1 setor
    mov si, 3               ; 3 tentativas

disk_write_retry:
    stc
    int 13h
    jnc disk_write_ok       ; Se sucesso, sai

    call floppy_reset
    dec si
    test si, si
    jnz disk_write_retry

    stc                     ; Falhou
    popa
    ret

disk_write_ok:
    clc
    popa
    ret
	

; --------------------------------------------------------------------------
; disk_load_cluster -- Carrega o conteúdo de um cluster (FAT12) para disk_buffer
; --------------------------------------------------------------------------
; Entrada: AX = número do cluster a ser lido
; Saída: CF = 0 → sucesso, CF = 1 → falha
; Preserva: registradores com PUSHA/POPA
; --------------------------------------------------------------------------

disk_load_cluster:
    pusha

    ; --- Converte cluster para LBA ---
    mov bx, ax              ; BX = cluster
    add bx, 31              ; Dados começam no setor 31
    mov ax, bx              ; AX = LBA
    call lba_to_chs         ; Converte LBA → CHS

    ; --- Prepara leitura ---
    mov ah, 0x02            ; INT 13h função: ler setor
    mov al, 0x01            ; 1 setor
    mov si, 3               ; 3 tentativas

disk_load_retry:
    stc
    int 13h
    jnc disk_load_ok        ; Se sucesso, sai

    call floppy_reset
    dec si
    test si, si
    jnz disk_load_retry

    stc                     ; Falhou
    popa
    ret

disk_load_ok:
    clc
    popa
    ret