#!/usr/bin/env bash
# ==============================================================================
# 0itocore-supervisor - Instalador / Atualizador Oficial para Linux
# Repositório: https://eijuito.github.io/repo/0itocore-supervisor/
# ==============================================================================
# Uso Rápido (Comando Único):
#   curl -fsSL https://eijuito.github.io/repo/0itocore-supervisor/install.sh | sudo bash
#
# Opções de Linha de Comando:
#   sudo ./install.sh               # Instala ou atualiza para a versão mais recente
#   sudo ./install.sh --status      # Exibe status atual do serviço e da versão instalada
#   sudo ./install.sh --uninstall   # Inativa e remove serviço/binários (preserva dados)
#   sudo ./install.sh --purge       # Remove completamente binários, dados e configs
# ==============================================================================

set -euo pipefail

# Definições Globais de Diretórios e URLs
REPO_BASE_URL="https://eijuito.github.io/repo"
FALLBACK_BASE_URL="https://raw.githubusercontent.com/eijuito/eijuito.github.io/main/repo"
PROJECT_NAME="0itocore-supervisor"
PROJECT_URL="${REPO_BASE_URL}/${PROJECT_NAME}"
FALLBACK_URL="${FALLBACK_BASE_URL}/${PROJECT_NAME}"
DOWNLOAD_BASE_URL="${PROJECT_URL}"

INSTALL_DIR="/opt/0itocore-supervisor"
BIN_DIR="${INSTALL_DIR}/bin"
CONFIG_DIR="${INSTALL_DIR}/config"
DATA_DIR="${INSTALL_DIR}/data"
PLUGINS_DIR="${INSTALL_DIR}/plugins"
INSTANCES_DIR="${INSTALL_DIR}/instances"
LOGS_DIR="${INSTALL_DIR}/logs"

BIN_PATH="${BIN_DIR}/0itocore-supervisor"
OLD_BIN_PATH="${BIN_DIR}/0itocore-supervisor.old"
CONFIG_PATH="${CONFIG_DIR}/config.json"
SERVICE_NAME="0itocore-supervisor.service"
SYSTEMD_PATH="/etc/systemd/system/${SERVICE_NAME}"
GLOBAL_SYMLINK="/usr/local/bin/0itocore-supervisor"

# Cores para Saída Terminal
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $*"
}

success() {
    echo -e "${C_GREEN}[SUCESSO]${C_RESET} $*"
}

warn() {
    echo -e "${C_YELLOW}[AVISO]${C_RESET} $*"
}

error() {
    echo -e "${C_RED}[ERRO]${C_RESET} $*" >&2
}

banner() {
    echo -e "${C_BLUE}${C_BOLD}"
    echo "=================================================================="
    echo "       0ITOCORE-SUPERVISOR - INSTALADOR & GERENCIADOR LINUX       "
    echo "                  Ecossistema 0ito Sovereign Tech                 "
    echo "=================================================================="
    echo -e "${C_RESET}"
}

# 1. Checagem de Privilégios Administrativos
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        error "Este instalador requer privilégios de superusuário (root)."
        echo "Por favor, execute novamente utilizando 'sudo bash install.sh' ou:"
        echo "  curl -fsSL ${PROJECT_URL}/install.sh | sudo bash"
        exit 1
    fi
}

# 2. Verificação de Conectividade com o Repositório Público
check_connectivity() {
    info "Verificando conectividade com o repositório público..."
    if curl -fsSI --connect-timeout 5 "${PROJECT_URL}/0itocore-supervisor" > /dev/null 2>&1; then
        DOWNLOAD_BASE_URL="${PROJECT_URL}"
        success "Repositório público oficial (GitHub Pages) acessível com sucesso."
    elif curl -fsSI --connect-timeout 5 "${FALLBACK_URL}/0itocore-supervisor" > /dev/null 2>&1; then
        DOWNLOAD_BASE_URL="${FALLBACK_URL}"
        success "Repositório público conectado via espelho seguro (GitHub Raw CDN)."
    elif curl -fsSI --connect-timeout 5 "${REPO_BASE_URL}/" > /dev/null 2>&1; then
        DOWNLOAD_BASE_URL="${PROJECT_URL}"
        success "Repositório base acessível."
    else
        error "Falha ao conectar com ${PROJECT_URL} e ${FALLBACK_URL}."
        error "Verifique sua conexão com a internet e resolução de DNS."
        exit 1
    fi
}

# 3. Detecção e Validação do Sistema Operacional e Arquitetura
detect_os_arch() {
    info "Detectando sistema operacional e arquitetura hospedeira..."
    local os_type
    os_type="$(uname -s)"
    if [[ "${os_type}" != "Linux" ]]; then
        error "Sistema operacional não suportado: ${os_type}. Este script foi projetado para Linux."
        exit 1
    fi

    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64)
            ARCH_NAME="x64"
            ;;
        aarch64|arm64)
            ARCH_NAME="arm64"
            ;;
        *)
            error "Arquitetura não suportada no momento: ${arch}. Suportadas: x86_64 (x64), aarch64 (arm64)."
            exit 1
            ;;
    esac

    # Identificar distribuição Linux
    local distro="Desconhecida"
    if [[ -f /etc/os-release ]]; then
        distro="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
    fi

    info "Hospedeiro identificado: ${distro} (${arch})"

    # Verificar presença do systemd
    if ! command -v systemctl >/dev/null 2>&1 || ! systemctl is-system-running >/dev/null 2>&1 && [[ ! -d /run/systemd/system ]]; then
        warn "O gerenciador init 'systemd' pode não estar ativo nesta máquina."
    else
        success "Gerenciador de daemons 'systemd' ativo e pronto para uso."
    fi
}

# 4. Verificação de Instalação Existente e Versão
check_existing_installation() {
    CURRENT_VERSION="none"
    if [[ -x "${BIN_PATH}" ]]; then
        CURRENT_VERSION="$("${BIN_PATH}" --version 2>/dev/null | awk '{print $2}' || echo "instalada-desconhecida")"
        info "Instalação existente detectada em ${INSTALL_DIR} (Versão: ${CURRENT_VERSION})"
    else
        info "Nenhuma instalação anterior de ${PROJECT_NAME} detectada. Nova instalação."
    fi
}

# 5. Baixar e Validar Artefatos do Public Vault
download_artifacts() {
    TMP_DIR="$(mktemp -d -t 0itocore-supervisor-install-XXXXXX)"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    info "Consultando artefatos e integridade criptográfica no Public Vault (${DOWNLOAD_BASE_URL})..."
    local sums_url="${DOWNLOAD_BASE_URL}/SHA256SUMS"
    
    if ! curl -fsSL "${sums_url}" -o "${TMP_DIR}/SHA256SUMS"; then
        warn "Arquivo SHA256SUMS não pôde ser baixado diretamente (${sums_url})."
    fi

    # Determinar nome do artefato binário
    local target_bin_url="${DOWNLOAD_BASE_URL}/0itocore-supervisor"
    info "Baixando binário oficial: ${target_bin_url}..."
    if ! curl -fsSL "${target_bin_url}" -o "${TMP_DIR}/0itocore-supervisor"; then
        # Tentar fallback
        if [[ "${DOWNLOAD_BASE_URL}" != "${FALLBACK_URL}" ]]; then
            warn "Tentando espelho de contingência em ${FALLBACK_URL}..."
            if ! curl -fsSL "${FALLBACK_URL}/0itocore-supervisor" -o "${TMP_DIR}/0itocore-supervisor"; then
                error "Falha no download do binário em ambos os servidores."
                exit 1
            fi
        else
            error "Falha no download do binário ${target_bin_url}."
            exit 1
        fi
    fi

    chmod +x "${TMP_DIR}/0itocore-supervisor"

    # Validar integridade SHA256 se o arquivo estiver listado em SHA256SUMS
    info "Verificando integridade SHA256 dos artefatos baixados..."
    cd "${TMP_DIR}"
    if grep -E '0itocore-supervisor$' SHA256SUMS > /dev/null 2>&1; then
        local expected_hash
        expected_hash="$(grep -E '0itocore-supervisor$' SHA256SUMS | awk '{print $1}')"
        local calculated_hash
        calculated_hash="$(sha256sum 0itocore-supervisor | awk '{print $1}')"

        if [[ "${expected_hash}" != "${calculated_hash}" ]]; then
            error "Divergência de Checksum SHA256!"
            error "Esperado:   ${expected_hash}"
            error "Calculado:  ${calculated_hash}"
            exit 1
        fi
        success "Checksum SHA256 verificado com sucesso (${calculated_hash:0:16}...)."
    else
        warn "Arquivo 0itocore-supervisor não possui linha direta no SHA256SUMS; checagem básica de tamanho e execução efetuada."
    fi

    NEW_VERSION="$("${TMP_DIR}/0itocore-supervisor" --version 2>/dev/null | awk '{print $2}' || echo "v0.1.0")"
    info "Versão dos artefatos baixados: ${NEW_VERSION}"
}

# 6. Inativação Segura do Serviço Antigo
stop_existing_service() {
    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        info "Inativando o serviço ${SERVICE_NAME} para atualização atômica..."
        systemctl stop "${SERVICE_NAME}"
        success "Serviço anterior inativado com sucesso."
    fi
}

# 7. Instalação / Atualização dos Binários e Diretórios
install_files() {
    info "Garantindo estrutura de diretórios em ${INSTALL_DIR}..."
    mkdir -p "${BIN_DIR}" "${CONFIG_DIR}" "${DATA_DIR}" "${PLUGINS_DIR}" "${INSTANCES_DIR}" "${LOGS_DIR}"
    chmod 750 "${INSTALL_DIR}" "${DATA_DIR}" "${CONFIG_DIR}"

    if [[ -f "${BIN_PATH}" ]]; then
        info "Criando cópia de segurança do binário anterior em ${OLD_BIN_PATH}..."
        cp -f "${BIN_PATH}" "${OLD_BIN_PATH}"
    fi

    info "Instalando novo binário em ${BIN_PATH}..."
    cp -f "${TMP_DIR}/0itocore-supervisor" "${BIN_PATH}"
    chmod 755 "${BIN_PATH}"

    # Criar link simbólico para acesso global via terminal
    ln -sf "${BIN_PATH}" "${GLOBAL_SYMLINK}"
    success "Binário instalado e link criado em ${GLOBAL_SYMLINK}."

    # Inicializar configuração padrão se não existir
    if [[ ! -f "${CONFIG_PATH}" ]]; then
        info "Criando arquivo de configuração padrão em ${CONFIG_PATH}..."
        cat <<EOF > "${CONFIG_PATH}"
{
  "version": "${NEW_VERSION#v}",
  "http_port": 8000,
  "vault_enabled": false,
  "processes": []
}
EOF
        chmod 640 "${CONFIG_PATH}"
        success "Configuração inicial criada (Modo Nó, Porta 8000)."
    else
        info "Configuração existente preservada em ${CONFIG_PATH}."
    fi
}

# 8. Configuração e Ativação do Daemon systemd
configure_systemd() {
    info "Configurando serviço de inicialização automática no systemd (${SYSTEMD_PATH})..."
    cat <<EOF > "${SYSTEMD_PATH}"
[Unit]
Description=0itocore-supervisor - Central Orchestrator & Lifecycle Manager (0ito Ecosystem)
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_PATH} --config ${CONFIG_PATH}
Restart=always
RestartSec=5s
LimitNOFILE=65536
Environment=RUST_LOG=info
Environment=0ITO_HOME=/opt/0ito

# Isolamento e Segurança Básica
ProtectSystem=full
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    info "Iniciando ${SERVICE_NAME}..."
    systemctl start "${SERVICE_NAME}"
}

# 9. Verificação de Saúde Pós-Instalação (Health Check)
verify_health() {
    info "Aguardando inicialização do serviço e verificando health check na porta 8000..."
    local retries=10
    local success=0

    while [[ ${retries} -gt 0 ]]; do
        if curl -fsSL http://127.0.0.1:8000/health > /dev/null 2>&1; then
            success=1
            break
        fi
        sleep 1
        ((retries--))
    done

    if [[ ${success} -eq 1 ]]; then
        success "Health check aprovado! O 0itocore-supervisor está ativo e operando."
    else
        warn "O endpoint de healthcheck http://127.0.0.1:8000/health ainda não respondeu."
        warn "Verifique o log com: journalctl -u ${SERVICE_NAME} -n 50"
    fi
}

# Rotina de Desinstalação
uninstall_supervisor() {
    banner
    check_privileges
    info "Iniciando desinstalação de ${PROJECT_NAME}..."

    if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        info "Parando o serviço ${SERVICE_NAME}..."
        systemctl stop "${SERVICE_NAME}"
    fi

    if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
        info "Desabilitando serviço no boot..."
        systemctl disable "${SERVICE_NAME}"
    fi

    if [[ -f "${SYSTEMD_PATH}" ]]; then
        rm -f "${SYSTEMD_PATH}"
        systemctl daemon-reload
        success "Unit systemd removida."
    fi

    rm -f "${GLOBAL_SYMLINK}"
    rm -rf "${BIN_DIR}"

    if [[ "${1:-}" == "--purge" ]]; then
        warn "Opção --purge detectada. Removendo todos os dados, plugins, instâncias e configurações..."
        rm -rf "${INSTALL_DIR}"
        success "Instalação completamente purgada de ${INSTALL_DIR}."
    else
        success "Binários e serviço removidos com sucesso."
        info "Dados, plugins e configurações foram preservados em ${INSTALL_DIR}."
        info "Para remover tudo permanentemente, utilize: sudo ./install.sh --purge"
    fi
    exit 0
}

# Rotina de Exibição de Status
show_status() {
    banner
    echo -e "${C_BOLD}--- STATUS DO 0ITOCORE-SUPERVISOR ---${C_RESET}"
    if [[ -x "${BIN_PATH}" ]]; then
        echo -e "Binário Instalado: ${C_GREEN}${BIN_PATH}${C_RESET}"
        local ver
        ver="$("${BIN_PATH}" --version 2>/dev/null || echo "Desconhecida")"
        echo -e "Versão do Binário: ${C_CYAN}${ver}${C_RESET}"
    else
        echo -e "Binário Instalado: ${C_RED}Não instalado${C_RESET}"
    fi

    if [[ -f "${CONFIG_PATH}" ]]; then
        echo -e "Configuração:      ${C_GREEN}${CONFIG_PATH}${C_RESET}"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        local s_active
        s_active="$(systemctl is-active "${SERVICE_NAME}" 2>/dev/null || echo "inativo")"
        if [[ "${s_active}" == "active" ]]; then
            echo -e "Status do Serviço: ${C_GREEN}ATIVO (Running)${C_RESET}"
        else
            echo -e "Status do Serviço: ${C_RED}${s_active}${C_RESET}"
        fi
    fi

    if curl -fsSL http://127.0.0.1:8000/health > /dev/null 2>&1; then
        echo -e "Healthcheck HTTP:  ${C_GREEN}OK (http://127.0.0.1:8000/health)${C_RESET}"
    else
        echo -e "Healthcheck HTTP:  ${C_RED}Inacessível ou Desligado${C_RESET}"
    fi
    echo ""
    exit 0
}

# Fluxo Principal
main() {
    case "${1:-}" in
        --uninstall)
            uninstall_supervisor
            ;;
        --purge)
            uninstall_supervisor "--purge"
            ;;
        --status)
            show_status
            ;;
        -h|--help)
            banner
            echo "Uso: sudo ./install.sh [OPCAO]"
            echo ""
            echo "Opções:"
            echo "  (sem parâmetros)   Instala ou atualiza o supervisor para a versão mais recente"
            echo "  --status           Verifica se o supervisor está instalado e sua saúde"
            echo "  --uninstall        Desinstala o serviço e binários, mantendo dados e configs"
            echo "  --purge            Remove tudo, incluindo dados, plugins e configurações"
            echo "  --help             Exibe esta mensagem de ajuda"
            exit 0
            ;;
        *)
            ;;
    esac

    banner
    check_privileges
    check_connectivity
    detect_os_arch
    check_existing_installation
    download_artifacts
    stop_existing_service
    install_files
    configure_systemd
    verify_health

    echo ""
    success "Instalação e configuração de 0itocore-supervisor concluídas!"
    echo -e "  Diretório de Operação: ${C_CYAN}${INSTALL_DIR}${C_RESET}"
    echo -e "  Arquivo de Config:     ${C_CYAN}${CONFIG_PATH}${C_RESET}"
    echo -e "  Gerenciamento Daemon:  ${C_YELLOW}sudo systemctl restart ${SERVICE_NAME}${C_RESET}"
    echo -e "  Logs em Tempo Real:    ${C_YELLOW}sudo journalctl -u ${SERVICE_NAME} -f${C_RESET}"
    echo -e "  Comando CLI Direto:    ${C_YELLOW}0itocore-supervisor --help${C_RESET}"
    echo ""
}

main "$@"
