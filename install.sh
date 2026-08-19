#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="zabbix-domain-monitor"
SCRIPT_NAME="zabbix_domain_monitor.sh"
INSTALL_PATH="/usr/local/bin/${SCRIPT_NAME}"
CACHE_DIR="/tmp/zabbix_domain_cache"

if [ "$(id -u)" -ne 0 ]; then
    echo "Erro: execute como root ou usando sudo."
    echo "Exemplo: sudo bash install.sh"
    exit 1
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Instalando ${PROJECT_NAME}"

install_dependencies_debian() {
    apt-get update
    apt-get install -y whois util-linux coreutils
}

install_dependencies_rhel() {
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y whois util-linux coreutils
    else
        yum install -y whois util-linux coreutils
    fi
}

install_dependencies_suse() {
    zypper --non-interactive install whois util-linux coreutils
}

missing_deps=0

for cmd in whois flock; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_deps=1
    fi
done

if [ "$missing_deps" -eq 1 ]; then
    echo "==> Dependências ausentes. Tentando instalar automaticamente..."

    if command -v apt-get >/dev/null 2>&1; then
        install_dependencies_debian
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        install_dependencies_rhel
    elif command -v zypper >/dev/null 2>&1; then
        install_dependencies_suse
    else
        echo "Erro: gerenciador de pacotes não suportado."
        echo "Instale manualmente as dependências: whois, flock/util-linux."
        exit 1
    fi
fi

for cmd in whois flock; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Erro: dependência não encontrada após instalação: $cmd"
        exit 1
    fi
done

echo "==> Instalando script em ${INSTALL_PATH}"
install -m 755 "${BASE_DIR}/${SCRIPT_NAME}" "$INSTALL_PATH"

echo "==> Criando diretório de cache em ${CACHE_DIR}"
mkdir -p "$CACHE_DIR"
chmod 1777 "$CACHE_DIR"

touch "${CACHE_DIR}/.ratelimit_lock" "${CACHE_DIR}/.ratelimit_timer"
chmod 666 "${CACHE_DIR}/.ratelimit_lock" "${CACHE_DIR}/.ratelimit_timer"

echo "==> Instalando UserParameter do Zabbix"

USERPARAM_SOURCE="${BASE_DIR}/zabbix_agentd.d/userparameter_domain.conf"

if [ ! -f "$USERPARAM_SOURCE" ]; then
    echo "Erro: arquivo não encontrado: ${USERPARAM_SOURCE}"
    exit 1
fi

installed_userparam=0

if [ -d /etc/zabbix/zabbix_agentd.d ]; then
    install -m 644 "$USERPARAM_SOURCE" /etc/zabbix/zabbix_agentd.d/userparameter_domain.conf
    echo "UserParameter instalado em /etc/zabbix/zabbix_agentd.d/userparameter_domain.conf"
    installed_userparam=1
fi

if [ -d /etc/zabbix/zabbix_agent2.d ]; then
    install -m 644 "$USERPARAM_SOURCE" /etc/zabbix/zabbix_agent2.d/userparameter_domain.conf
    echo "UserParameter instalado em /etc/zabbix/zabbix_agent2.d/userparameter_domain.conf"
    installed_userparam=1
fi

if [ "$installed_userparam" -eq 0 ]; then
    echo "Aviso: diretório padrão do Zabbix Agent não encontrado."
    echo "Criando /etc/zabbix/zabbix_agentd.d/"
    mkdir -p /etc/zabbix/zabbix_agentd.d
    install -m 644 "$USERPARAM_SOURCE" /etc/zabbix/zabbix_agentd.d/userparameter_domain.conf
fi

echo "==> Reiniciando Zabbix Agent, se disponível"

restarted=0

if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files | grep -q '^zabbix-agent2\.service'; then
        systemctl restart zabbix-agent2
        echo "Serviço reiniciado: zabbix-agent2"
        restarted=1
    fi

    if systemctl list-unit-files | grep -q '^zabbix-agent\.service'; then
        systemctl restart zabbix-agent
        echo "Serviço reiniciado: zabbix-agent"
        restarted=1
    fi
fi

if [ "$restarted" -eq 0 ]; then
    echo "Aviso: nenhum serviço zabbix-agent ou zabbix-agent2 foi reiniciado automaticamente."
    echo "Reinicie manualmente o agente Zabbix."
fi

echo
echo "Instalação concluída."
echo
echo "Teste manual:"
echo "  ${INSTALL_PATH} expira empresa.com.br"
echo
echo "Teste pelo agente Zabbix:"
echo "  zabbix_agentd -t 'domain.whois[expira,empresa.com.br]'"
echo
echo "Observação:"
echo "  Para muitos domínios em carga fria, considere ajustar Timeout no Zabbix Agent para 30 ou 60 segundos."
