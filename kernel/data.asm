; ==================================================================
; src/kernel/data.asm - Dados do FEP OS
; ==================================================================

; --------------------------------------------------------------
; Definições de caracteres especiais (usados em ASCII Art e UI)
; --------------------------------------------------------------
%define CHAR_ULCORNER   0C9h    ; ╔ canto superior esquerdo
%define CHAR_URCORNER   0BBh    ; ╗ canto superior direito
%define CHAR_LLCORNER   0C8h    ; ╚ canto inferior esquerdo
%define CHAR_LRCORNER   0BCh    ; ╝ canto inferior direito
%define CHAR_HLINE      0CDh    ; ═ linha horizontal
%define CHAR_VLINE      0BAh    ; ║ linha vertical
%define CHAR_BLOCK      0DBh    ; █ bloco cheio (usado em ASCII art/logos)
%define CHAR_SHADE_DARK 0B2h    ; ▓ sombreamento (efeitos visuais)
%define SPACE           0x20    ; espaço em branco (ASCII 32)

; --------------------------------------------------------------
; Constantes do sistema
; --------------------------------------------------------------
COMMAND_BUFFER_SIZE equ 128     ; Tamanho máximo do buffer de comandos do shell
                                ; → garante que o usuário não digite mais que 127 chars
                                ; (1 byte é reservado para o terminador nulo)

; --------------------------------------------------------------
; Área de Listagem de Diretório
; --------------------------------------------------------------
dirlist times 1024 db 0         ; Buffer de 1024 bytes para armazenar listagens de diretório
                                ; Usado quando o comando "ls" ou similar é chamado
                                ; Armazena temporariamente os nomes de arquivos/pastas

ROOT_ENTRIES equ 224            ; Número de entradas no diretório raiz (para disquete 1.44MB)
                                ; Esse valor é padrão do FAT12 para disquetes de 1.44MB
                                ; → significa que o root dir pode ter até 224 arquivos/pastas

; ==================================================================
; String comando LS
; ==================================================================
dir_tag db ' [DIR]',0
                                ; Sufixo usado pelo comando "ls"
                                ; Quando um item listado for diretório,
                                ; essa string é concatenada ao nome → "NOME [DIR]"
                                ; Terminada em 0 (string C-style)

; --------------------------------------------------------------
; Mensagens do Sistema
; --------------------------------------------------------------
msg_welcome:
    db 'FEP OS 16-bit Iniciado!', 0x0D, 0x0A, 0
    ; Mensagem de boas-vindas exibida ao iniciar o sistema
    ; Inclui CR (0x0D) + LF (0x0A) para quebra de linha
    ; Terminador 0 no final

msg_prompt:
    db 'FEP-OS> ', 0
    ; Prompt do shell ("> ") indicando que o usuário pode digitar comandos
    ; Terminador 0 no final

msg_newline:
    db 0x0D, 0x0A, 0
    ; Sequência de nova linha (CR+LF), usada para formatação de saída
    ; Terminador 0 no final

msg_ver:
    db "FepOS v0.1 (Assembly, FAT12)", 0x0D, 0x0A, 0
    ; Mensagem de versão do sistema
    ; Mostra versão atual e tecnologias usadas
    ; Inclui CR+LF no final e terminador 0


; ------------------------------------------------------------
; variável que guarda o caminho atual
; por enquanto só a raiz "/" pwd
; ------------------------------------------------------------
current_path db '/',0           ; String que representa o caminho atual.
                                ; Inicialmente é apenas "/" (raiz).
                                ; Terminada em 0 → formato de string C-style.
                                ; Usada pelo comando "pwd" e para exibir o diretório atual.

current_dir_cluster dw 0        ; Cluster atual no sistema de arquivos FAT12.
                                ; 0 = diretório raiz (root directory).
                                ; Quando o usuário fizer "cd" para outro diretório,
                                ; esse valor será atualizado para o cluster correspondente.


; --------------------------------------------------------------
; Strings de Comando Reconhecidas pelo Shell
; --------------------------------------------------------------
; Objetivo:
;   Definir os comandos que o shell reconhece como válidos.
;   Cada comando é armazenado como uma string terminada em zero (byte nulo),
;   o que facilita a comparação com a entrada do usuário.
;
; Funcionamento:
;   - O shell percorre essas definições e compara com o texto digitado.
;   - Quando encontra uma correspondência, executa a rotina associada.
;   - A comparação é feita com funções como string_compare ou string_search.
;
; Observações:
;   - Os comandos são definidos como rótulos com `db` (define byte).
;   - O terminador nulo (`0`) é essencial para delimitar o fim da string.
;   - Alguns comandos são aliases (ex: "clear" é equivalente a "cls").
; --------------------------------------------------------------

cmd_cls:       db 'cls', 0        ; "cls" → limpa a tela
cmd_clear:     db 'clear', 0      ; "clear" → alias para "cls"
cmd_ajuda:     db 'ajuda', 0      ; "ajuda" → lista de comandos disponíveis
cmd_echo:      db 'echo', 0       ; "echo" → imprime texto no ecrã
cmd_exit:      db 'exit', 0       ; "exit" → sai do shell
cmd_shutdown:  db 'shutdown', 0   ; "shutdown" → desliga o sistema
cmd_ls:        db 'ls', 0         ; "ls" → lista os ficheiros do diretório atual
cmd_ver:       db 'ver', 0        ; "ver" → mostra a versão do SO
cmd_time:      db 'time', 0       ; "time" → mostra a hora
cmd_date:      db 'date', 0       ; "date" → mostra a data
cmd_datetime:  db 'datetime', 0   ; "datetime" → mostra data e hora
cmd_mem:       db 'mem', 0        ; "mem" → mostra a quantidade de memória
cmd_reboot:    db 'reboot', 0     ; "reboot" → reinicia o sistema
cmd_cat:       db 'cat', 0        ; "cat" → lê e exibe arquivos no ecrã
cmd_touch:     db 'touch', 0      ; "touch" → cria um arquivo vazio
cmd_rm:        db 'rm', 0         ; "rm" → deleta um arquivo
cmd_cp:        db 'cp', 0         ; "cp" → copia um arquivo
cmd_mv:        db 'mv', 0         ; "mv" → move ou renomeia um arquivo
cmd_df:        db 'df', 0         ; "df" → mostra consumo do disco
cmd_pwd:       db 'pwd', 0        ; "pwd" → mostra diretório atual
cmd_grep:      db 'grep', 0       ; "grep" → busca por padrões em arquivos
cmd_wc:        db 'wc', 0         ; "wc" → conta linhas, palavras e bytes
cmd_exec:      db 'exec', 0       ; "exec" → executa um programa externo
cmd_head:      db 'head', 0       ; "head" → mostra primeiras linhas de um arquivo
cmd_tail:      db 'tail', 0       ; "tail" → mostra últimas linhas de um arquivo
cmd_more:      db 'more', 0       ; "more" → paginação de saída longa
cmd_hexdump:   db 'hexdump', 0    ; "hexdump" → exibe conteúdo hexadecimal
cmd_fat:       db 'fatdump', 0    ; "fatdump" → mostra estrutura da FAT (sistema de arquivos)
cmd_mkdir:     db 'mkdir', 0      ; "mkdir" → cria diretório
cmd_rmdir:     db 'rmdir', 0      ; "rmdir" → remove diretório
cmd_cd:        db 'cd', 0         ; "cd" → muda de diretório
cmd_edit:      db 'edit', 0       ; "edit" → editor de texto simples

; --------------------------------------------------------------
; Mensagens auxiliares para o comando "cat"
; --------------------------------------------------------------
; Essas mensagens são exibidas em situações de erro ao usar o comando "cat".

cat_nofilename_msg: db 'Nome do arquivo nao fornecido.', 0x0D, 0x0A, 0
; Exibida quando o usuário digita "cat" sem especificar o nome do arquivo.
; 0x0D = Carriage Return, 0x0A = Line Feed → quebra de linha no console.

cat_notfound_msg:   db 'Arquivo nao encontrado.', 0x0D, 0x0A, 0
; Exibida quando o arquivo solicitado não existe no diretório atual.

; --------------------------------------------------------------------------
; Variáveis globais da função write_file
; --------------------------------------------------------------------------
; Objetivo:
;   Armazenar dados temporários e parâmetros usados durante a escrita de arquivos.
;   Essas variáveis são utilizadas para calcular espaço necessário, localizar
;   clusters livres e controlar o progresso da operação.
;
; Observações:
;   - As variáveis são do tipo `dw` (word, 16 bits).
;   - `times 128 dw 0` reserva espaço para até 128 clusters livres.
; --------------------------------------------------------------------------
write_file_filesize        dw 0      ; Tamanho total do arquivo a ser escrito
write_file_cluster         dw 0      ; Cluster atual sendo usado
write_file_count           dw 0      ; Contador de clusters já usados
write_file_location        dw 0      ; Localização inicial do arquivo
write_file_clusters_needed dw 0      ; Quantidade de clusters necessários
write_file_filename        dw 0      ; Ponteiro para o nome do arquivo
write_file_free_clusters   times 128 dw 0 ; Lista de clusters livres disponíveis

cp_exists_msg       db 'O arquivo de destino já existe', 13, 10, 0
                                ; Mensagem exibida quando o comando "cp"
                                ; tenta copiar um arquivo para um destino
                                ; que já existe.
                                ; Inclui CR (13) + LF (10) para quebra de linha.
                                ; Terminada em 0 (string C-style).

execute_cp_dst      dw 0        ; Cluster de destino usado na cópia de arquivo.
                                ; Durante a execução do "cp", esse valor
                                ; guarda o cluster inicial do arquivo de destino.

remove_file_cluster dw 0        ; Cluster a ser liberado na remoção de arquivo.
                                ; Usado pelo comando "rm" para marcar
                                ; qual cluster deve ser liberado na FAT.

remove_dir_cluster  dw 0        ; Cluster a ser liberado na remoção de diretório.
                                ; Usado pelo comando "rmdir" para remover
                                ; diretórios e atualizar a FAT.

; --------------------------------------------------------------
; Variáveis globais usadas pelo carregador de arquivos (load_file)
; --------------------------------------------------------------
; Essas variáveis são usadas para armazenar informações temporárias
; durante a leitura de arquivos do disco.

load_file_cluster:       dw 0
; Armazena o número do primeiro cluster do arquivo a ser carregado.

load_file_filename_loc:  dw 0
; Endereço (offset) onde o nome do arquivo está armazenado na memória.

load_file_file_size:     dw 0
; Tamanho do arquivo em bytes (ou setores, dependendo da implementação).

msg_debug_load_loop_end: db 'DEBUG: Fim Loop Leitura.', 0
; Mensagem de depuração para indicar o fim do loop de leitura de clusters.
; Observação: manter essa mensagem de debug para arrumar uma pane 
; de buffer overflow, já que garantem alinhamento de memória.

load_file_load_address_linear: dw 0
; Endereço linear na memória onde o conteúdo do arquivo será carregado.

LOAD_BUFFER_LINEAR  equ 0x4000 ; Endereço linear 64KB (ou 0x1000:0000)
; Ou um valor ainda maior se quiseres mais segurança, ex: 0x20000 (128KB)
; Vamos usar 0x10000 por agora.

LOAD_BUFFER_SEGMENT  equ LOAD_BUFFER_LINEAR/16  ; = 0x1000
; --------------------------------------------------------------
; Strings de Mensagem do Shell
; --------------------------------------------------------------
msg_unknown_cmd:
    db 'Comando desconhecido: ', 0
    ; Mensagem exibida quando o usuário digita um comando inválido
; --------------------------------------------------------------
; msg_ajuda: Texto de ajuda exibido quando o usuário digita "ajuda"
; --------------------------------------------------------------
; Objetivo:
;   Listar todos os comandos disponíveis no shell com breve descrição.
;   Exibido como resposta ao comando "ajuda".
;
; Observações:
;   - Cada linha termina com CR (0x0D) + LF (0x0A) para quebra de linha.
;   - A string termina com byte 0 (null-terminated).
; --------------------------------------------------------------
msg_ajuda:
    db 'Comandos disponiveis:', 0x0D, 0x0A
    db '  ver                 - Versao do SO', 0x0D, 0x0A
    db '  cls/clear           - Limpa o ecra', 0x0D, 0x0A
    db '  ajuda               - Mostra esta ajuda', 0x0D, 0x0A
    db '  echo [msg]          - Imprime [msg] no ecra', 0x0D, 0x0A
    db '  ls                  - Lista os ficheiros', 0x0D, 0x0A
    db '  exec [arq]          - Executa comandos apartir de um arquivo', 0x0D, 0x0A
    db '  cat [arq]           - Mostra o conteudo de um arquivo', 0x0D, 0x0A
    db '  head [arq]          - Mostra as 10 primeiras linhas de um arquivo', 0x0D, 0x0A
    db '  tail [arq]          - Mostra as 10 ultimas linhas de um arquivo', 0x0D, 0x0A
    db '  grep <padrao> [arq] - Captura uma correspondencia em um arquivo', 0x0D, 0x0A
    db '  wc [arq]            - Conta quantas linhas, palavras um arquivo possui', 0x0D, 0x0A
    db '  cp [arq] [arq2]     - Copia um arquivo', 0x0D, 0x0A
    db '  touch [arq]         - Cria um arquivo vazio', 0x0D, 0x0A
    db '  rm [arq]            - Deleta um arquivo', 0x0D, 0x0A
    db '  mv [arq] [arq2]     - Move ou Renomeia um arquivo', 0x0D, 0x0A
    db '  df                  - Mostra espaco do disco', 0x0D, 0x0A
    db '  time                - Mostra a hora', 0x0D, 0x0A
    db '  date                - Mostra a data', 0x0D, 0x0A
    db '  datetime            - Mostra a data e hora', 0x0D, 0x0A
    db '  mem                 - Mostra a quantidade de memoria', 0x0D, 0x0A
    db '  reboot              - Reincia o sistema', 0x0D, 0x0A
    db '  exit/shutdown       - Desliga o sistema', 0x0D, 0x0A, 0

; --------------------------------------------------------------
; Mensagens de sistema
; --------------------------------------------------------------
msg_shutdown:
    db 'Desligando o sistema...', 0x0D, 0x0A, 0
    ; Exibida ao encerrar o sistema

msg_safe_to_shutdown:
    db 'O sistema parou. Pode desligar o computador.', 0
    ; Indica que é seguro desligar a máquina

msg_reboot:
    db 'Reiniciando o sistema...', 0
    ; Exibida ao reiniciar o sistema

; --------------------------------------------------------------
; Mensagem de erro de leitura
; --------------------------------------------------------------
read_failure:
    db 'Falha ao ler o disco!', 0x0D, 0x0A, 0
    ; Exibida quando ocorre erro na leitura do disco

; --------------------------------------------------------------
; Buffers de Trabalho
; --------------------------------------------------------------
command_buffer:
    resb COMMAND_BUFFER_SIZE
    ; Buffer de entrada de comandos do usuário (tamanho definido por constante)
	
;COMMAND_BUFFER_SIZE equ 128

;command_buffer times COMMAND_BUFFER_SIZE db 0  ; buffer de entrada

directory_buffer:
    resb 7168
    ; Buffer para armazenar dados do diretório raiz (7 KB)
    ; Usado para leitura, listagem e manipulação de arquivos

; ==================================================================
; BPB (BIOS Parameter Block) DATA
; ==================================================================
; Estrutura reservada para armazenar o BPB e EBR copiados do setor
; de boot. Esses dados descrevem o layout do sistema de arquivos FAT12.
; ==================================================================
bpb_data_start:
    bpb_oem:                 resb 8    ; Identificador OEM
    bpb_bytes_per_sector:    resw 1    ; Bytes por setor (normalmente 512)
    bpb_sectors_per_cluster: resb 1    ; Setores por cluster
    bpb_reserved_sectors:    resw 1    ; Setores reservados (inclui setor de boot)
    bpb_fat_count:           resb 1    ; Número de cópias da FAT
    bpb_dir_entries_count:   resw 1    ; Máximo de entradas no diretório raiz
    bpb_total_sectors:       resw 1    ; Total de setores do volume
    bpb_media_descriptor_type: resb 1  ; Tipo de mídia (ex.: 0xF0 = disquete)
    bpb_sectors_per_fat:     resw 1    ; Setores por FAT
    bpb_sectors_per_track:   resw 1    ; Setores por trilha
    bpb_heads:               resw 1    ; Número de cabeças (faces do disco)
    bpb_hidden_sectors:      resd 1    ; Setores ocultos antes da partição
    bpb_large_sector_count:  resd 1    ; Total de setores (para discos grandes)
    ebr_drive_number:        resb 1    ; Número da unidade (0 = A:)
    ebr_reserved:            resb 1    ; Reservado
    ebr_signature:           resb 1    ; Assinatura de boot (0x29)
    ebr_volume_id:           resd 1    ; Número de série do volume
    ebr_volume_label:        resb 11   ; Rótulo do volume (11 caracteres)
    ebr_system_id:           resb 8    ; Identificação do sistema de arquivos (ex.: "FAT12")
bpb_data_end: