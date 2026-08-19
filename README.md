# Zabbix Domain Monitor

Monitoramento de dominios via WHOIS com cache local e rate limit para Zabbix.

## Funcionalidades

- Cache de 5 minutos (`/tmp/zabbix_domain_cache`)
- Rate limit global de 5 segundos entre consultas `whois`
- Enfileiramento automatico quando multiplos dominios expiram juntos
- Previne timeout ao processar varios dominios simultaneos

## Requisitos

- `bash`
- `whois`
- `flock` (util-linux)
- Zabbix Agent 2 ou Zabbix Agent legado

## Instalacao

Execute como **root**:

```bash
git clone <repo>
cd zabbix-domain-monitor
sudo bash install.sh



zabbix-domain-monitor/
├── README.md
├── install.sh
├── zabbix_domain_monitor.sh
├── .gitignore
├── zabbix_agentd.d/
│   └── userparameter_domain.conf
└── zabbix_template/
    └── template_domain_monitor.yaml
