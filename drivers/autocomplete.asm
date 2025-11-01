; --------------------------------------------------------------
; Autocomplete com suporte a múltiplos matches
; --------------------------------------------------------------
; Entrada: SI = buffer atual (prefixo digitado)
; Saída: completa se houver match único, ou lista se houver múltiplos

msg_space   db ' ',0
;msg_newline db 0x0D,0x0A,0
common_buf_size equ 32
common_buf times common_buf_size db 0
last_tab_prefix_len db 0  ; guarda tamanho do prefixo quando TAB foi pressionado
	
autocomplete:
    push si
    push di
    push bx
    push cx
    push dx

    ; prefix_len atual
    mov si, command_buffer
    xor dx, dx
.len_prefix:
    mov al, [si]
    cmp al, 0
    je .have_len
    inc dx
    inc si
    jmp .len_prefix
.have_len:

    ; verifica double TAB: se last_tab_prefix_len == prefix_len, forçar listagem
    mov al, [last_tab_prefix_len]
    cmp al, dl              ; dl = low byte de dx (prefix_len <= 255 no seu caso)
    jne .update_tab_len     ; não é double TAB → fluxo normal
    mov bl, 1               ; flag doubleTab
    jmp .flow_start
.update_tab_len:
    mov [last_tab_prefix_len], dl
    xor bl, bl              ; flag doubleTab = 0

.flow_start:
    ; zera common_buf
	mov di, common_buf
	mov cx, common_buf_size   ; defina com 'equ' ou 'times'
	rep stosb                 ; zera CX bytes a partir de DI
.zero_common:
    mov byte [di], 0
    inc di
    loop .zero_common

    ; contador de matches
    xor cx, cx              ; cx = 0 matches

%macro TEST_CMD 1
    mov di, %1
    mov si, command_buffer
    call string_startswith
    cmp al, 1
    jne %%skip
    inc cx
    ; merge common_buf
    cmp cx, 1
    jne %%merge
    ; primeiro match: copia %1 → common_buf
    mov si, %1
    mov di, common_buf
%%copy_first:
    mov al, [si]
    mov [di], al
    cmp al, 0
    je %%skip
    inc si
    inc di
    jmp %%copy_first
%%merge:
    ; reduzir common_buf até divergência com %1
    mov si, common_buf
    mov di, %1
%%merge_loop:
    mov al, [si]
    mov bl, [di]
    cmp al, 0
    je %%trim_done
    cmp al, bl
    je %%advance
    mov byte [si], 0
    jmp %%trim_done
%%advance:
    inc si
    inc di
    jmp %%merge_loop
%%trim_done:
%%skip:
%endmacro

    TEST_CMD cmd_cls
    TEST_CMD cmd_clear
    TEST_CMD cmd_ajuda
    TEST_CMD cmd_ver
    TEST_CMD cmd_mem
    TEST_CMD cmd_echo
    TEST_CMD cmd_exit
    TEST_CMD cmd_shutdown
    TEST_CMD cmd_ls
    TEST_CMD cmd_time
    TEST_CMD cmd_date
    TEST_CMD cmd_datetime
    TEST_CMD cmd_reboot
    TEST_CMD cmd_cat
    TEST_CMD cmd_touch
    TEST_CMD cmd_rm
    TEST_CMD cmd_cp
    TEST_CMD cmd_mv
    TEST_CMD cmd_df
    TEST_CMD cmd_pwd
    TEST_CMD cmd_wc
    TEST_CMD cmd_grep
    TEST_CMD cmd_exec
    TEST_CMD cmd_head
    TEST_CMD cmd_tail
    TEST_CMD cmd_more
    TEST_CMD cmd_mkdir
    TEST_CMD cmd_rmdir
    TEST_CMD cmd_cd
    TEST_CMD cmd_edit
    TEST_CMD cmd_hexdump
    TEST_CMD cmd_fat

    ; se nenhum match → sair
    cmp cx, 0
    je .done

    ; common_len
    mov si, common_buf
    xor bx, bx
.len_common:
    mov al, [si]
    cmp al, 0
    je .compare_len
    inc bx
    inc si
    jmp .len_common
.compare_len:

    ; se double TAB → listar, independente de expansão possível
    cmp bl, 1
    je .list_all

    ; se houver expansão além do prefixo, completa delta
    ; dx = prefix_len, bx = common_len
    cmp bx, dx
    jbe .maybe_list        ; comum não maior que prefixo → não expandir

    ; expandir delta
    mov si, command_buffer
    mov di, common_buf
    call autocomplete_fill_partial   ; usa dx como prefix_len
    jmp .done

.maybe_list:
    ; se apenas um match → completar tudo
    cmp cx, 1
    je .complete_single

    ; múltiplos matches sem expansão → listar
    jmp .list_all

.complete_single:
    mov si, command_buffer
    mov di, common_buf
    call autocomplete_fill
    jmp .done

.list_all:
    mov si, msg_newline
    call print_string

%macro PRINT_MATCH 1
    mov di, %1
    mov si, command_buffer
    call string_startswith
    cmp al, 1
    jne %%skip
    mov si, %1
    call print_string
    mov si, msg_space
    call print_string
%%skip:
%endmacro

    PRINT_MATCH cmd_cls
    PRINT_MATCH cmd_clear
    PRINT_MATCH cmd_ajuda
    PRINT_MATCH cmd_ver
    PRINT_MATCH cmd_mem
    PRINT_MATCH cmd_echo
    PRINT_MATCH cmd_exit
    PRINT_MATCH cmd_shutdown
    PRINT_MATCH cmd_ls
    PRINT_MATCH cmd_time
    PRINT_MATCH cmd_date
    PRINT_MATCH cmd_datetime
    PRINT_MATCH cmd_reboot
    PRINT_MATCH cmd_cat
    PRINT_MATCH cmd_touch
    PRINT_MATCH cmd_rm
    PRINT_MATCH cmd_cp
    PRINT_MATCH cmd_mv
    PRINT_MATCH cmd_df
    PRINT_MATCH cmd_pwd
    PRINT_MATCH cmd_wc
    PRINT_MATCH cmd_grep
    PRINT_MATCH cmd_exec
    PRINT_MATCH cmd_head
    PRINT_MATCH cmd_tail
    PRINT_MATCH cmd_more
    PRINT_MATCH cmd_mkdir
    PRINT_MATCH cmd_rmdir
    PRINT_MATCH cmd_cd
    PRINT_MATCH cmd_edit
    PRINT_MATCH cmd_hexdump
    PRINT_MATCH cmd_fat

    mov si, msg_newline
    call print_string
    mov si, msg_prompt
    call print_string
    mov si, command_buffer
    call print_string
    jmp .done

.done:
    pop dx
    pop cx
    pop bx
    pop di
    pop si
    ret
	
	
; Verifica se [SI] é prefixo de [DI]
; Retorna AL=1 se sim, AL=0 caso contrário
string_startswith:
    push si
    push di
.loop:
    mov al, [si]
    cmp al, 0
    je .prefix_ok
    mov bl, [di]
    cmp al, bl
    jne .not_prefix
    inc si
    inc di
    jmp .loop
.prefix_ok:
    mov al, 1
    jmp .done
.not_prefix:
    mov al, 0
.done:
    pop di
    pop si
    ret
; Copia apenas o "delta" de DI (comando completo)
; para o fim de SI (buffer do usuário).
; Entrada:
;   SI = command_buffer
;   DI = comando completo (ex: "date")
;   DX = comprimento do prefixo já digitado
autocomplete_fill_partial:
    push si
    push di
    push cx

    ; Avança SI até o fim do buffer
.find_end:
    mov al, [si]
    cmp al, 0
    je .align_di
    inc si
    jmp .find_end

    ; Avança DI até depois do prefixo já digitado
.align_di:
    mov cx, dx
.skip_prefix:
    cmp cx, 0
    je .copy_rest
    inc di
    dec cx
    jmp .skip_prefix

    ; Copia o restante do comando
.copy_rest:
    mov al, [di]
    cmp al, 0
    je .done
    mov [si], al
    inc si
    inc di
    ; ecoa na tela
    call print_char
    jmp .copy_rest

.done:
    mov byte [si], 0   ; fecha string com terminador nulo

    pop cx
    pop di
    pop si
    ret

; Copia DI inteiro para o fim de SI
autocomplete_fill:
    push si
    push di
.find_end:
    mov al, [si]
    cmp al, 0
    je .copy
    inc si
    jmp .find_end
.copy:
    mov al, [di]
    cmp al, 0
    je .done
    mov [si], al
    inc si
    inc di
    mov bl, 0Ah
    call print_char
    jmp .copy
.done:
    mov byte [si], 0
    pop di
    pop si
    ret