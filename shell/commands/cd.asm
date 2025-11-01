;; bugado precisa arrumar
cd:\
pusha

; DEBUG: entrada na função
mov si, cd_enter_msg
call print_string
call print_newline

; Converte nome para maiúsculas e formato FAT 8.3
call string_uppercase
call int_dir_convert
mov si, cd_debug_convert
call print_string
call print_newline

push ax                     ; nome convertido

; Decide onde buscar: root ou subdir
mov ax, [current_dir_cluster]
cmp ax, 0
je .read_root

; Subdiretório atual
call disk_load_cluster
jc .fail
mov si, cd_debug_load
call print_string
call print_newline
jmp .search

.read_root:
call disk_read_root_dir
jc .fail
mov si, cd_debug_root
call print_string
call print_newline

.search:
mov di, disk_buffer
pop ax                      ; nome convertido
call disk_get_root_entry
jc .fail
mov si, cd_debug_found
call print_string
call print_newline

; Garante que DI aponta para início da entrada
sub di, 11

; DEBUG: imprime os 32 bytes da entrada
mov cx, 32
mov si, di
.print_entry_loop:
mov al, [si]
call print_hex8
call print_char_space
inc si
loop .print_entry_loop
call print_newline

; Verifica se é diretório
mov al, [di+11]
test al, 0x10
jz .fail
mov si, cd_debug_dir
call print_string
call print_newline

; Lê cluster inicial
mov ax, [di+26]
mov si, cd_debug_cluster
call print_string
call print_hex16
call print_newline

; Verifica se é cluster válido
cmp ax, 2
jb .fail
cmp ax, 2847
ja .fail

; Atualiza diretório atual
mov [current_dir_cluster], ax
mov si, cd_debug_success
call print_string
call print_newline

clc
popa
ret

.fail:
mov si, cd_debug_fail
call print_string
call print_newline
stc
popa
ret

print_hex16:
pusha
mov cx, 4                  ; 4 dígitos hex
.hex_loop:
rol ax, 4
mov bl, al
and bl, 0x0F
cmp bl, 10
jb .digit
add bl, 'A' - 10
jmp .print
.digit:
add bl, '0'
.print:
mov al, bl
call print_char
loop .hex_loop
popa
ret

print_hex8:
pusha
mov ah, al
shr al, 4
call print_hex_digit
mov al, ah
and al, 0x0F
call print_hex_digit
popa
ret

print_hex_digit:
cmp al, 10
jl .num
add al, 'A' - 10
jmp .out
.num:
add al, '0'
.out:
call print_char
ret

print_char_space:
mov al, ' '
call print_char
ret

cd_enter_msg:       db 'Função CD chamada!', 0
cd_debug_convert:   db 'Nome convertido.', 0
cd_debug_load:      db 'Cluster carregado.', 0
cd_debug_root:      db 'Lendo root dir.', 0
cd_debug_found:     db 'Entrada encontrada.', 0
cd_debug_dir:       db 'É um diretório.', 0
cd_debug_cluster:   db 'Cluster = ', 0
cd_debug_success:   db 'Diretório atualizado com sucesso.', 0
cd_debug_fail:      db 'Falha ao entrar no diretório.', 0