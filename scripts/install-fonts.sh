#!/bin/bash

# Script avançado para instalação de fontes
# Autor: Assistant
# Versão: 2.0

set -euo pipefail

# Configurações padrão
FONT_DIR=""
INSTALL_DIR=""
FORCE_INSTALL=false
VERBOSE=false
DRY_RUN=false

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    local level=$1
    shift
    case $level in
        "ERROR")   echo -e "${RED}❌ $*${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $*${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $*${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  $*${NC}" ;;
        *)         echo "$*" ;;
    esac
}

# Função de ajuda
show_help() {
    cat << EOF
Instalador de Fontes v2.0

USO:
    $0 [OPÇÕES] [DIRETÓRIO]

DESCRIÇÃO:
    Instala todas as fontes encontradas no diretório especificado.
    Suporta formatos: TTF, OTF, WOFF, WOFF2

OPÇÕES:
    -d, --dir DIR       Diretório das fontes (padrão: diretório atual)
    -i, --install DIR   Diretório de instalação personalizado
    -f, --force         Sobrescreve fontes existentes
    -v, --verbose       Modo verboso
    -n, --dry-run       Simula a instalação sem executar
    -h, --help          Mostra esta ajuda

EXEMPLOS:
    $0                          # Instala fontes do diretório atual
    $0 /path/to/fonts           # Instala fontes do diretório especificado
    $0 -f -v ~/Downloads/fonts  # Instalação forçada e verbosa
    $0 -n fonts/                # Simula instalação

EOF
}

# Detecta sistema operacional e define diretório padrão
detect_system() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        INSTALL_DIR="$HOME/.local/share/fonts"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        INSTALL_DIR="$HOME/Library/Fonts"
    else
        log "ERROR" "Sistema operacional não suportado: $OSTYPE"
        exit 1
    fi
}

# Processa argumentos da linha de comando
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                FONT_DIR="$2"
                shift 2
                ;;
            -i|--install)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log "ERROR" "Opção desconhecida: $1"
                show_help
                exit 1
                ;;
            *)
                FONT_DIR="$1"
                shift
                ;;
        esac
    done
}

# Valida configurações
validate_config() {
    # Define diretório padrão se não especificado
    FONT_DIR="${FONT_DIR:-.}"
    
    # Verifica se o diretório de fontes existe
    if [[ ! -d "$FONT_DIR" ]]; then
        log "ERROR" "Diretório não encontrado: $FONT_DIR"
        exit 1
    fi
    
    # Cria diretório de instalação se necessário
    if [[ ! -d "$INSTALL_DIR" ]] && [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$INSTALL_DIR"
        log "INFO" "Diretório criado: $INSTALL_DIR"
    fi
}

# Instala uma fonte
install_font() {
    local font_path="$1"
    local font_name=$(basename "$font_path")
    local dest_path="$INSTALL_DIR/$font_name"
    
    # Verifica se já existe
    if [[ -f "$dest_path" ]] && [[ "$FORCE_INSTALL" == false ]]; then
        log "WARNING" "Fonte já existe: $font_name (use -f para sobrescrever)"
        return 1
    fi
    
    # Modo dry-run
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY-RUN] Instalaria: $font_name"
        return 0
    fi
    
    # Instala a fonte
    if cp "$font_path" "$dest_path"; then
        log "SUCCESS" "Instalada: $font_name"
        return 0
    else
        log "ERROR" "Falha ao instalar: $font_name"
        return 1
    fi
}

# Função principal
main() {
    local installed=0
    local skipped=0
    local failed=0
    
    detect_system
    parse_args "$@"
    validate_config
    
    log "INFO" "Diretório de origem: $FONT_DIR"
    log "INFO" "Diretório de instalação: $INSTALL_DIR"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "WARNING" "MODO SIMULAÇÃO - Nenhuma alteração será feita"
    fi
    
    echo ""
    
    # Processa todas as fontes
    while IFS= read -r -d '' font; do
        if install_font "$font"; then
            ((installed++))
        else
            if [[ -f "$INSTALL_DIR/$(basename "$font")" ]]; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
    done < <(find "$FONT_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.woff" -o -iname "*.woff2" \) -print0)
    
    # Atualiza cache de fontes (Linux)
    if [[ "$OSTYPE" == "linux-gnu"* ]] && [[ "$DRY_RUN" == false ]] && [[ $installed -gt 0 ]]; then
        echo ""
        log "INFO" "Atualizando cache de fontes..."
        fc-cache -f -v "$INSTALL_DIR" >/dev/null 2>&1
    fi
    
    # Relatório final
    echo ""
    echo "==================== RELATÓRIO ===================="
    log "SUCCESS" "Fontes instaladas: $installed"
    log "WARNING" "Fontes puladas: $skipped"
    log "ERROR" "Falhas: $failed"
    echo "=================================================="
}

# Executa o script
main "$@"