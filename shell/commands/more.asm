; ==================================================================
;                 FUNÇÃO EXECUTE_MORE 
; Mostra um ficheiro página por página (24 linhas)
; Comandos: q=Sair, Espaço=Próxima Página, Enter=Próxima Linha
; ==================================================================
execute_more:
    pusha
    push ds
    push es

    ; 1. Validar Argumento
    mov si, bp
    cmp byte [si], 0
    je .more_usage

    ; 2. Carregar Ficheiro
    mov ax, bp
    mov cx, LOAD_BUFFER_LINEAR
    call load_file
    jc .more_not_found
    mov cx, bx ; CX = Tamanho 16-bit (contador de bytes restantes)

    ; 3. Preparar Loop
    mov ax, LOAD_BUFFER_SEGMENT 
    mov es, ax          ; ES:BX aponta para o ficheiro carregado
    mov bx, 0x0000      ; BX = Ponteiro de leitura
    
    mov di, line_buffer ; DI = Ponteiro de escrita (buffer da linha)
    
    mov bp, 0           ; BP = Contador de linhas nesta página (0-23)
    
.more_loop:
    ; Verifica se terminámos os bytes
    cmp cx, 0
    je .more_process_last_line ; Se sim, processa última linha e sai

    mov al, [es:bx] ; Lê byte
    
    ; ***** INÍCIO DA CORREÇÃO (Segment Wrap >64KB) *****
    inc bx          ; Avança ponteiro de leitura (offset)
    cmp bx, 0       ; O BX deu a volta de 0xFFFF para 0x0000?
    jne .more_no_seg_inc
    ; Sim, BX deu a volta. Avança o segmento ES
    mov ax, es
    add ax, 0x1000  ; Avança 64KB (0x1000 * 16)
    mov es, ax
    .more_no_seg_inc:
    ; ***** FIM DA CORREÇÃO *****
    
    dec cx          ; Decrementa contador de bytes

    cmp al, 0x0D ; Ignora CR
    je .more_loop

    cmp al, 0x0A ; É LF (Newline)?
    je .more_process_line
    
    ; É char normal. Adiciona ao buffer.
    push di ; Guarda DI temporariamente
    ; Calcula offset atual dentro de line_buffer
    ; Precisamos usar um registo temporário, como DX
    mov dx, di
    sub dx, line_buffer 
    cmp dx, 255         ; Buffer cheio? (Offset 0-255)
    pop di ; Restaura DI
    jge .more_process_line ; Se sim, processa

    mov byte [di], al
    inc di
    jmp .more_loop ; Continua a ler bytes

.more_process_line:
    mov byte [di], 0    ; Termina a string

    ; Verifica se a linha estava vazia
    cmp di, line_buffer 
    je .more_reset_and_continue ; Se sim, não imprime, só reseta

    ; --- Imprime a linha ---
    ; Salva estado do loop principal ANTES de chamar print_string
    push bx ; Salva ponteiro do ficheiro
    push cx ; Salva contador de bytes
    push bp ; Salva contador de linhas
    push es ; Salva segmento
    
    mov si, line_buffer
    call print_string
    call print_newline
    
    ; Restaura estado do loop principal
    pop es
    pop bp 
    pop cx 
    pop bx 

    inc bp ; Incrementa contador de linhas nesta página
    
    ; --- Lógica de Pausa ---
    cmp bp, 24 ; Chegou a 24 linhas?
    jl .more_reset_and_continue ; Se não, continua

.more_pause:
    ; Sim, 24 linhas. Mostra prompt e espera tecla.
    ; Salva estado do loop principal ANTES de chamar print/read
    push bx 
    push cx
    push bp
    push es

    mov si, more_prompt_msg
    call print_string
    
    call read_char ; Espera tecla (retorna AL=ASCII, AH=ScanCode)
    
    ; Apaga o prompt antes de continuar
    mov si, more_prompt_bs
    call print_string
    mov si, more_prompt_clear
    call print_string
    mov si, more_prompt_bs
    call print_string

    ; Restaura estado do loop principal
    pop es
    pop bp 
    pop cx
    pop bx

    ; Analisa a tecla pressionada (AL)
    cmp al, 'q'
    je .more_exit ; 'q' -> Sair

    cmp al, ' ' ; Espaço (' ')
    je .more_next_page ; Espaço -> Próxima página (reseta contador)

    cmp al, 0x0D ; Enter (CR)
    je .more_next_line ; Enter -> Próxima linha (contador = 23)

    ; Qualquer outra tecla: Trata como Enter (avança 1 linha)
    jmp .more_next_line

.more_next_page:
    mov bp, 0 ; Reseta contador de linhas
    jmp .more_reset_and_continue

.more_next_line:
    mov bp, 23 ; Próxima linha vai causar pausa de novo
    jmp .more_reset_and_continue

.more_reset_and_continue:
    mov di, line_buffer ; Reseta DI para a próxima linha
    jmp .more_loop      ; Volta ao loop de leitura de bytes

.more_process_last_line:
    ; Fim do ficheiro (CX=0). Processa a última linha se houver algo no buffer.
    mov byte [di], 0
    cmp di, line_buffer
    je .more_exit ; Buffer vazio, sai
    
    mov si, line_buffer
    call print_string
    call print_newline
    jmp .more_exit

.more_usage:
    mov si, more_usage_msg
    call print_string
    jmp .more_exit

.more_not_found:
    mov si, cat_notfound_msg
    call print_string
    
.more_exit:
    pop es
    pop ds
    popa
    ret
	
; --------------------------------------------------------------
; Mensagens auxiliares para "more"
; --------------------------------------------------------------
; Objetivo:
;   Definir mensagens de texto utilizadas pelo comando "more",
;   que exibe conteúdo paginado no terminal.
;
; Funcionamento:
;   - "more" mostra parte do conteúdo e aguarda interação do usuário.
;   - Essas mensagens são exibidas como prompts ou instruções.
;   - São strings terminadas em zero (null-terminated), prontas para exibição.
;
; Observações:
;   - O caractere 13 (CR) e 10 (LF) representam quebra de linha (enter).
;   - "Backspace" (código 8) é usado para reposicionar o cursor.
;   - Espaços e backspaces são usados para limpar ou sobrescrever o prompt.
; --------------------------------------------------------------

more_usage_msg:     db 'Uso: more <arquivo>', 13, 10, 0
                    ; Mensagem de uso → instrução de como usar o comando
                    ; Inclui quebra de linha (CR+LF) ao final

more_prompt_msg:    db '-- More --', 0
                    ; Prompt exibido ao pausar a saída paginada

more_prompt_clear:  db '          ', 0
                    ; Espaços usados para sobrescrever o prompt anterior
                    ; Útil para "limpar" a área do terminal

more_prompt_bs:     db 10 dup (8), 0
                    ; Sequência de 10 backspaces (código ASCII 8)
                    ; Move o cursor para trás para sobrescrever o prompt
