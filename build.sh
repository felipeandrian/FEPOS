#!/bin/bash
# ----------------------------------------------------------------------
# Script de Automação de Build e Execução para FEP OS (FAT12 Formatado)
# Requer: NASM, dd, mkfs.fat, mtools (mcopy) e QEMU.
# ----------------------------------------------------------------------

# Definições de Caminho e Nomes
BOOTLOADER_SRC="bootloader/boot.asm"
KERNEL_SRC="kernel/main.asm"
OUTPUT_BOOT="BOOT.BIN"
OUTPUT_KERNEL="KERNEL.BIN"
IMAGE_DRIVE="FEPOS.IMG"
IMAGE_SIZE_KB=1440 # 1.44MB

# Variáveis de Configuração do NASM
# -Isrc/: Inclui a pasta src para encontrar todos os módulos
NASM_OPTIONS="-f bin"

# Comando QEMU (Executa como disquete 3.5")
QEMU_CMD="qemu-system-i386 -fda $IMAGE_DRIVE -no-reboot"

# --- Funções do Script ---

# 1. Limpa arquivos gerados
clean_build() {
    echo "Limpando binários e imagem..."
    rm -f $OUTPUT_BOOT $OUTPUT_KERNEL $IMAGE_DRIVE *.log
}

# 2. Compila Kernel e Bootloader
compile_binaries() {
    echo "Compilando Bootloader..."
    nasm $NASM_OPTIONS $BOOTLOADER_SRC -o $OUTPUT_BOOT
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha na compilação do Bootloader."
        exit 1
    fi

    echo "Compilando KERNEL..."
    nasm $NASM_OPTIONS $KERNEL_SRC -o $OUTPUT_KERNEL
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha na compilação do Kernel."
        exit 1
    fi
    echo "Binários compilados com sucesso."
}

# 3. Cria e Formata a Imagem FAT12
create_and_format_image() {
    echo "1. Criando imagem vazia de $IMAGE_SIZE_KB KB..."
    # Cria uma imagem de 1.44MB (1440 blocos de 1KB)
    dd if=/dev/zero of=$IMAGE_DRIVE bs=1k count=$IMAGE_SIZE_KB 2>/dev/null

    echo "2. Formatando imagem como FAT12..."
    # Formata a imagem. -I indica que é uma imagem, -F 12 força FAT12.
    mkfs.fat -F 12 -n "FEPOS" $IMAGE_DRIVE -I

    echo "3. Instalando Bootloader no primeiro setor (VBR)..."
    # Instala o bootloader no setor 0. bs=512, count=1 garante que só o VBR é sobrescrito.
    dd if=$OUTPUT_BOOT of=$IMAGE_DRIVE bs=512 count=1 conv=notrunc 2>/dev/null
}

# 4. Copia o Kernel e Outros Arquivos (Usando mtools)
copy_files() {
    echo "4. Copiando KERNEL.BIN para a raiz da imagem..."
    # -i especifica o arquivo de imagem, ::/ é o diretório raiz.
    mcopy -i $IMAGE_DRIVE $OUTPUT_KERNEL ::/
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha ao copiar o kernel. Certifique-se de que o nome 'KERNEL.BIN' (em 8.3) corresponde ao que o bootloader procura."
        exit 1
    fi
    
    # Se você tiver arquivos de teste, pode copiá-los aqui:
    # mcopy -i $IMAGE_DRIVE src/teste.txt ::/
    
    echo "Imagem de disco concluída."
}


# --- Funções de Execução ---

build_all() {
    clean_build
    compile_binaries
    create_and_format_image
    copy_files
}

run_qemu() {
    if [ ! -f $IMAGE_DRIVE ]; then
        echo "Imagem de disco ($IMAGE_DRIVE) não encontrada. Executando build completo primeiro..."
        build_all
    fi
    echo "5. Emulando (QEMU)..."
    $QEMU_CMD
}

# --- Trata argumentos ---

case "$1" in
    compile)
        build_all
        ;;
    run)
        run_qemu
        ;;
    clean)
        clean_build
        ;;
    *)
        echo "Uso: $0 {compile|run|clean}"
        echo "  compile - Compila o kernel e cria a imagem de disco formatada."
        echo "  run     - Executa a imagem no QEMU."
        echo "  clean   - Remove arquivos temporários e binários."
        exit 1
esac