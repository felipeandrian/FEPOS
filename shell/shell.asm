; ==================================================================
; src/shell/shell.asm - Funções do Shell
; ==================================================================

; ------------------------------------------------------------------
; process_command
; ------------------------------------------------------------------
; Objetivo:
;   Processar o comando digitado pelo usuário no buffer de entrada,
;   identificar qual comando foi solicitado e chamar a rotina
;   correspondente (cls, ajuda, echo, ls, shutdown, etc.).
;
; Contrato:
;   Entrada:
;     - O comando já foi digitado pelo usuário e está em command_buffer.
;   Saída:
;     - Executa a rotina correspondente ao comando.
;     - Se comando não reconhecido, chama unknown_command.
;
; Fluxo:
;   1. Finaliza a string digitada (inserindo terminador nulo).
;   2. Imprime uma nova linha para separar o prompt da saída.
;   3. Verifica se o buffer está vazio → volta ao shell_loop.
;   4. Chama parse_command (normaliza entrada, remove espaços, etc.).
;   5. Compara a string com cada comando conhecido.
;   6. Se encontrar correspondência, salta para a rotina de execução.
;   7. Caso contrário, chama unknown_command.
; ------------------------------------------------------------------
process_command:
    mov byte [di], 0                ; Coloca terminador nulo no final do comando
                                    ; (DI aponta para o fim do buffer de entrada)

    mov si, msg_newline             ; SI = ponteiro para string de nova linha
    call print_string               ; Imprime quebra de linha (separa prompt da saída)

    mov si, command_buffer          ; SI = início do buffer de comando
    cmp byte [si], 0                ; Verifica se o usuário não digitou nada
    je process_done                   ; Se vazio, volta ao loop principal do shell

    call parse_command              ; Normaliza o comando (ex.: remove espaços extras)
    mov bp, di                      ; BP = ponteiro auxiliar (pode ser usado em parse)

 ; --------------------------------------------------------------
; Comparação com comandos conhecidos
; --------------------------------------------------------------
; Estratégia:
;   - SI = ponteiro para comando digitado pelo usuário
;   - DI = ponteiro para string de comando conhecido (ex.: "cls")
;   - string_compare compara SI e DI:
;       → AL = 1 se iguais
;       → AL = 0 se diferentes
;   - Se iguais, salta para a rotina de execução correspondente
; --------------------------------------------------------------

    mov di, cmd_cls
    call string_compare
    cmp al, 1
    je execute_cls              ; "cls" → limpar tela

    mov di, cmd_clear
    call string_compare
    cmp al, 1
    je execute_cls              ; "clear" → alias de "cls"

    mov di, cmd_ajuda
    call string_compare
    cmp al, 1
    je execute_ajuda            ; "ajuda" → mostra lista de comandos

    mov di, cmd_ver
    call string_compare
    cmp al, 1
    je execute_ver              ; "ver" → mostra versão do SO

    mov di, cmd_mem
    call string_compare
    cmp al, 1
    je execute_mem              ; "mem" → mostra memória disponível

    mov di, cmd_echo
    call string_compare
    cmp al, 1
    je execute_echo             ; "echo" → imprime texto

    mov di, cmd_exit
    call string_compare
    cmp al, 1
    je execute_shutdown         ; "exit" → sair/desligar

    mov di, cmd_shutdown
    call string_compare
    cmp al, 1
    je execute_shutdown_apm     ; "shutdown" → alias de "exit"

    mov di, cmd_ls
    call string_compare
    cmp al, 1
    je execute_ls               ; "ls" → lista arquivos

    ; --- comando time ---
    mov di, cmd_time
    call string_compare
    cmp al, 1
    je execute_time             ; "time" → mostra hora

    ; --- comando date ---
    mov di, cmd_date
    call string_compare
    cmp al, 1
    je execute_date             ; "date" → mostra data

    mov di, cmd_datetime
    call string_compare
    cmp al, 1
    je execute_datetime         ; "datetime" → mostra data e hora

    mov di, cmd_reboot
    call string_compare
    cmp al, 1
    je execute_reboot           ; "reboot" → reinicia sistema

    mov di, cmd_cat
    call string_compare
    cmp al, 1
    je execute_cat              ; "cat" → mostra conteúdo de arquivo
	
	mov di, cmd_touch
	call string_compare
	cmp al, 1
	je execute_touch			; "touch" → cria um arquivo vazio
	
	mov di, cmd_rm
	call string_compare
	cmp al, 1
	je execute_rm				; "rm" → Deleta um arquivo

	mov di, cmd_cp
	call string_compare
	cmp al, 1
	je execute_cp				; "cp" → Copia um arquivo
	
	
	mov di, cmd_mv
	call string_compare
	cmp al, 1
	je execute_mv				; "mv" → renomeia ou move um arquivo
	
	mov di, cmd_df
	call string_compare
	cmp al, 1
	je execute_df				; "df" → espaço de disco
	
	mov di, cmd_pwd
	call string_compare
	cmp al, 1
	je execute_pwd             ; "pwd" → path
	
	mov di, cmd_wc
    call string_compare
    cmp al, 1
    je execute_wc           ; "wc" -> conta palavras
	
	mov di, cmd_grep
    call string_compare
    cmp al, 1
    je execute_grep         ; "grep" -> procura texto
	
	
	mov di, cmd_exec
    call string_compare
    cmp al, 1
    je execute_exec         ; "exec" -> executa script
	
	mov di, cmd_head
    call string_compare
    cmp al, 1
    je execute_head         ; "head" -> mostra 10 primeiras linhas
	

    mov di, cmd_tail
    call string_compare
    cmp al, 1
    je execute_tail         ; "tail" -> mostra 10 últimas linhas
	
	
	mov di, cmd_more
    call string_compare
    cmp al, 1
    je execute_more         ; "more" -> mostra ficheiro página a página
	
	
	mov di, cmd_mkdir
    call string_compare
    cmp al, 1
    je execute_mkdir         ; "more" -> mostra ficheiro página a página
	
	
	mov di, cmd_rmdir
    call string_compare
    cmp al, 1
    je execute_rmdir        ; "more" -> mostra ficheiro página a página
	
	mov di, cmd_cd
    call string_compare
    cmp al, 1
    je cd       ; "more" -> mostra ficheiro página a página
	
	mov di, cmd_edit
    call string_compare
    cmp al, 1
    je edit      ; "more" -> mostra ficheiro página a página
	
	
	
	mov di, cmd_hexdump
    call string_compare
    cmp al, 1
    je execute_hexdump      ; "hexdump" -> mostra dump hexadecimal
	
    mov di, cmd_fat
	call string_compare
	cmp al, 1
	je fatdump				; "fatdump" → mostra entradas fat12
	
	
	
; --------------------------------------------------------------
; Se nenhum comando foi reconhecido
; --------------------------------------------------------------
    jmp unknown_command         ; Executa rotina de comando desconhecido

process_done:
	mov byte [command_buffer], 0
    ret ; Retorna se o comando estava vazio
	


; --------------------------------------------------------------------------
; unknown_command -- Tratar comando inválido
; --------------------------------------------------------------------------
; Objetivo:
;   Informar ao usuário que o comando digitado não foi reconhecido.
;   Exibe uma mensagem padrão seguida do próprio comando digitado,
;   e então retorna ao loop principal do shell.
;
; Contrato:
;   Entrada:
;     - command_buffer contém o comando digitado pelo usuário.
;   Saída:
;     - Mensagem de erro exibida na tela.
;     - Retorna ao shell_loop para aguardar novo comando.
; --------------------------------------------------------------------------
unknown_command:
    mov si, msg_unknown_cmd         ; SI = ponteiro para mensagem padrão
    call print_string               ; Exibe mensagem "Comando desconhecido: " (por exemplo)

    mov si, command_buffer          ; SI = ponteiro para o comando digitado
    call print_string               ; Exibe o comando que o usuário digitou

    mov si, msg_newline             ; SI = ponteiro para string de nova linha (CR+LF)
    call print_string               ; Exibe quebra de linha para organizar saída

    ret                  ; Retorna ao loop principal do shell
	
		
; --------------------------------------------------------------------------
; parse_command -- Separar comando e argumentos
; --------------------------------------------------------------------------
; Objetivo:
;   Processar a string digitada pelo usuário em `command_buffer` e separar:
;     - O comando em si (ex.: "echo")
;     - O argumento (ex.: "Olá Mundo")
;
; Funcionamento:
;   - Percorre a string em busca do primeiro espaço.
;   - Se encontrar espaço:
;       * Substitui o espaço por terminador nulo (0).
;       * Assim, a primeira parte da string vira o comando isolado.
;       * DI passa a apontar para o início dos argumentos.
;       * SI é resetado para o início do buffer (comando).
;   - Se não encontrar espaço (string termina em 0):
;       * Não há argumentos.
;       * DI aponta para o terminador (fim da string).
;       * SI é resetado para o início do buffer (comando).
;
; Contrato:
;   Entrada:
;     SI = ponteiro para `command_buffer` (string digitada pelo usuário).
;   Saída:
;     SI = início do comando (command_buffer).
;     DI = início dos argumentos (ou terminador nulo se não houver).
; --------------------------------------------------------------------------
parse_command:
    parse_loop:
        mov al, [si]                ; AL = próximo caractere da string
        cmp al, ' '                 ; É espaço?
        je parse_found_space        ; Se sim, achamos separador comando/args
        cmp al, 0                   ; É terminador nulo?
        je parse_no_args            ; Se sim, não há argumentos
        inc si                      ; Avança para próximo caractere
        jmp parse_loop              ; Continua o loop

    ; --------------------------------------------------------------
    ; Caso tenha encontrado espaço
    ; --------------------------------------------------------------
    parse_found_space:
        mov byte [si], 0            ; Substitui espaço por terminador nulo
                                    ; Agora o comando termina aqui
        inc si                      ; SI = início dos argumentos
        mov di, si                  ; DI aponta para os argumentos
        mov si, command_buffer      ; SI volta para o início do comando
        ret

    ; --------------------------------------------------------------
    ; Caso não haja argumentos
    ; --------------------------------------------------------------
    parse_no_args:
        mov di, si                  ; DI aponta para o terminador nulo
        mov si, command_buffer      ; SI volta para o início do comando
        ret
