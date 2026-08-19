#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="zabbix-domain-monitor"

SCRIPT_NAME="zabbix_domain_monitor.sh"
SCRIPT_DIR="/etc/zabbix/scripts"
INSTALL_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

CACHE_DIR="/tmp/zabbix_domain_cache"

USERPARAM_FILE="userparameter_domain.conf"
USERPARAM_SOURCE_REL="zabbix_agentd.d/${USERPARAM_FILE}"

LOG_FILE="/tmp/zabbix_domain_monitor_install.log"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_SCRIPT="${BASE_DIR}/${SCRIPT_NAME}"
USERPARAM_SOURCE="${BASE_DIR}/${USERPARAM_SOURCE_REL}"

ZABBIX_AGENTD_USERPARAM_DIR="/etc/zabbix/zabbix_agentd.d"
ZABBIX_AGENT2_USERPARAM_DIR="/etc/zabbix/zabbix_agent2.d"

ZABBIX_AGENTD_USERPARAM_TARGET="${ZABBIX_AGENTD_USERPARAM_DIR}/${USERPARAM_FILE}"
ZABBIX_AGENT2_USERPARAM_TARGET="${ZABBIX_AGENT2_USERPARAM_DIR}/${USERPARAM_FILE}"

NEEDED_COMMANDS=("whois" "flock")
DEBIAN_PACKAGES=("whois" "util-linux" "coreutils")
RHEL_PACKAGES=("whois" "util-linux" "coreutils")
SUSE_PACKAGES=("whois" "util-linux" "coreutils")

UPDATED_EXISTING_FILES=0

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear || true
}

line() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

title() {
    clear_screen
    echo
    line
    echo "        🚀 ${PROJECT_NAME}"
    echo "        Monitoramento WHOIS para Zabbix"
    line
    echo
}

step() {
    echo
    echo "┌────────────────────────────────────────────────────────────────────┐"
    printf "│ %-66s │\n" "🔹 $1"
    echo "└────────────────────────────────────────────────────────────────────┘"
}

success() {
    echo "   ✅ $1"
}

warn() {
    echo "   ⚠️  $1"
}

error() {
    echo "   ❌ $1"
}

info() {
    echo "   ℹ️  $1"
}

finish_error() {
    echo
    error "$1"
    echo
    echo "Instalação finalizada com erro."
    echo "Log técnico, se existir: ${LOG_FILE}"
    echo
    exit 1
}

ask_update_existing_files() {
    local existing_files=()

    if [ -f "$INSTALL_PATH" ]; then
        existing_files+=("$INSTALL_PATH")
    fi

    if [ -f "$ZABBIX_AGENTD_USERPARAM_TARGET" ]; then
        existing_files+=("$ZABBIX_AGENTD_USERPARAM_TARGET")
    fi

    if [ -f "$ZABBIX_AGENT2_USERPARAM_TARGET" ]; then
        existing_files+=("$ZABBIX_AGENT2_USERPARAM_TARGET")
    fi

    if [ "${#existing_files[@]}" -eq 0 ]; then
        return 0
    fi

    step "Arquivos existentes encontrados"

    warn "Um ou mais arquivos de destino já existem:"
    echo

    for file in "${existing_files[@]}"; do
        echo "      - ${file}"
    done

    echo
    echo "   Deseja atualizar/substituir esses arquivos?"
    echo
    echo "   Opções aceitas:"
    echo "     Sim | S | s"
    echo "     Nao | N | n"
    echo

    read -r -p "   Informe sua opção: " USER_CHOICE

    case "$USER_CHOICE" in
        Sim|S|s)
            UPDATED_EXISTING_FILES=1
            success "Atualização autorizada pelo usuário."
            ;;
        Nao|N|n)
            warn "Atualização não autorizada. Nenhum arquivo foi alterado."
            echo
            echo "Instalação finalizada pelo usuário."
            echo
            exit 0
            ;;
        *)
            error "Opção incorreta: '${USER_CHOICE}'"
            echo
            echo "Informe apenas uma das opções aceitas: Sim, S, s, Nao, N ou n."
            echo "Instalação finalizada sem alterações."
            echo
            exit 1
            ;;
    esac
}

check_root() {
    step "Validação de permissões"

    if [ "$(id -u)" -ne 0 ]; then
        finish_error "Execute como root ou usando sudo. Exemplo: sudo bash install.sh"
    fi

    success "Permissão de root validada."
}

check_source_files() {
    step "Validação dos arquivos do projeto"

    if [ ! -f "$SOURCE_SCRIPT" ]; then
        finish_error "Arquivo obrigatório não encontrado: ${SOURCE_SCRIPT}"
    fi

    if [ ! -f "$USERPARAM_SOURCE" ]; then
        finish_error "Arquivo obrigatório não encontrado: ${USERPARAM_SOURCE}"
    fi

    success "Arquivos de origem encontrados."
}

install_dependencies_debian() {
    {
        apt-get update
        apt-get install -y "${DEBIAN_PACKAGES[@]}"
    } > "$LOG_FILE" 2>&1
}

install_dependencies_rhel() {
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y "${RHEL_PACKAGES[@]}" > "$LOG_FILE" 2>&1
    else
        yum install -y "${RHEL_PACKAGES[@]}" > "$LOG_FILE" 2>&1
    fi
}

install_dependencies_suse() {
    zypper --non-interactive install "${SUSE_PACKAGES[@]}" > "$LOG_FILE" 2>&1
}

check_and_install_dependencies() {
    local missing_commands=()

    step "Verificação de dependências"

    for cmd in "${NEEDED_COMMANDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ "${#missing_commands[@]}" -eq 0 ]; then
        success "Todas as dependências já estão instaladas."
        return 0
    fi

    warn "Dependências ausentes detectadas: ${missing_commands[*]}"
    info "Tentando instalar dependências obrigatórias de forma silenciosa..."

    if command -v apt-get >/dev/null 2>&1; then
        if ! install_dependencies_debian; then
            finish_error "Falha ao instalar dependências obrigatórias: ${DEBIAN_PACKAGES[*]}. Verifique os repositórios do sistema e chaves GPG."
        fi
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        if ! install_dependencies_rhel; then
            finish_error "Falha ao instalar dependências obrigatórias: ${RHEL_PACKAGES[*]}. Verifique os repositórios do sistema."
        fi
    elif command -v zypper >/dev/null 2>&1; then
        if ! install_dependencies_suse; then
            finish_error "Falha ao instalar dependências obrigatórias: ${SUSE_PACKAGES[*]}. Verifique os repositórios do sistema."
        fi
    else
        finish_error "Gerenciador de pacotes não suportado. Instale manualmente: whois, util-linux e coreutils."
    fi

    for cmd in "${NEEDED_COMMANDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            finish_error "Dependência obrigatória ainda ausente após tentativa de instalação: ${cmd}"
        fi
    done

    success "Dependências instaladas e validadas com sucesso."
}

install_main_script() {
    step "Instalação do script principal"

    mkdir -p "$SCRIPT_DIR"

    install -m 755 "$SOURCE_SCRIPT" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    success "Script instalado em: ${INSTALL_PATH}"
    success "Permissão de execução aplicada."
}

prepare_cache_dir() {
    step "Preparação do cache local"

    mkdir -p "$CACHE_DIR"
    chmod 1777 "$CACHE_DIR"

    touch "${CACHE_DIR}/.ratelimit_lock" "${CACHE_DIR}/.ratelimit_timer"
    chmod 666 "${CACHE_DIR}/.ratelimit_lock" "${CACHE_DIR}/.ratelimit_timer"

    success "Cache preparado em: ${CACHE_DIR}"
    success "Locks globais de rate limit preparados."
}

install_userparameters() {
    local installed_userparam=0

    step "Instalação dos UserParameters do Zabbix"

    if [ -d "$ZABBIX_AGENTD_USERPARAM_DIR" ]; then
        install -m 644 "$USERPARAM_SOURCE" "$ZABBIX_AGENTD_USERPARAM_TARGET"
        success "UserParameter instalado em: ${ZABBIX_AGENTD_USERPARAM_TARGET}"
        installed_userparam=1
    fi

    if [ -d "$ZABBIX_AGENT2_USERPARAM_DIR" ]; then
        install -m 644 "$USERPARAM_SOURCE" "$ZABBIX_AGENT2_USERPARAM_TARGET"
        success "UserParameter instalado em: ${ZABBIX_AGENT2_USERPARAM_TARGET}"
        installed_userparam=1
    fi

    if [ "$installed_userparam" -eq 0 ]; then
        warn "Diretórios padrão do Zabbix Agent não encontrados."
        info "Criando diretório padrão: ${ZABBIX_AGENTD_USERPARAM_DIR}"

        mkdir -p "$ZABBIX_AGENTD_USERPARAM_DIR"
        install -m 644 "$USERPARAM_SOURCE" "$ZABBIX_AGENTD_USERPARAM_TARGET"

        success "UserParameter instalado em: ${ZABBIX_AGENTD_USERPARAM_TARGET}"
    fi
}

restart_zabbix_agent() {
    local restarted=0

    step "Reinicialização do Zabbix Agent"

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files | grep -q '^zabbix-agent2\.service'; then
            if systemctl restart zabbix-agent2 >/dev/null 2>&1; then
                success "Serviço reiniciado: zabbix-agent2"
                restarted=1
            else
                warn "Não foi possível reiniciar automaticamente: zabbix-agent2"
            fi
        fi

        if systemctl list-unit-files | grep -q '^zabbix-agent\.service'; then
            if systemctl restart zabbix-agent >/dev/null 2>&1; then
                success "Serviço reiniciado: zabbix-agent"
                restarted=1
            else
                warn "Não foi possível reiniciar automaticamente: zabbix-agent"
            fi
        fi
    fi

    if [ "$restarted" -eq 0 ]; then
        warn "Nenhum serviço zabbix-agent ou zabbix-agent2 foi reiniciado automaticamente."
        info "Reinicie manualmente o agente Zabbix, se necessário."
    fi
}

show_final_message() {
    echo
    line
    echo "        ✅ Instalação concluída com sucesso"
    line
    echo

    if [ "$UPDATED_EXISTING_FILES" -eq 1 ]; then
        warn "Arquivos existentes foram atualizados conforme autorização."
        echo
    fi

    echo "📌 Script instalado em:"
    echo
    echo "   ${INSTALL_PATH}"
    echo

    echo "📌 Cache local:"
    echo
    echo "   ${CACHE_DIR}"
    echo

    echo "🧪 Teste manual:"
    echo
    echo "   ${INSTALL_PATH} expira empresa.com.br"
    echo

    echo "🧪 Teste pelo Zabbix Agent legado:"
    echo
    echo "   zabbix_agentd -t 'domain.expira[empresa.com.br]'"
    echo

    echo "🧪 Teste pelo Zabbix Agent 2:"
    echo
    echo "   zabbix_agent2 -t 'domain.expira[empresa.com.br]'"
    echo

    echo "⚙️  Observação:"
    echo
    echo "   Para muitos domínios em carga fria, considere ajustar Timeout"
    echo "   no Zabbix Agent para 30 ou 60 segundos."
    echo
}

main() {
    title

    check_root
    check_source_files
    ask_update_existing_files
    check_and_install_dependencies
    install_main_script
    prepare_cache_dir
    install_userparameters
    restart_zabbix_agent
    show_final_message
}

main "$@"
