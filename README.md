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
```


**O instalador realiza as seguintes ações:**

1. Verifica e instala dependências quando possível.
2. Instala o script principal em:
```bash
/usr/local/bin/zabbix_domain_monitor.sh
```
3. Cria e ajusta permissões do cache local:
```bash
/tmp/zabbix_domain_cache
```
4. Copia o arquivo de UserParameter para o diretório do Zabbix Agent ou Zabbix Agent 2.
5. Reinicia o serviço do Zabbix Agent quando disponível.


## Métricas disponíveis
Métrica	 = Descrição  
nome = Nome do domínio  
status = Status do domínio  
dono = Proprietário ou organização responsável  
donocnpj = Identificador do proprietário, quando disponível  
dononome = Nome do responsável  
pais = País do registro  
donoregistro = Código de contato do proprietário  
suporteregistro	Código de contato técnico  
dns1 = Primeiro servidor DNS  
dns2 = Segundo servidor DNS  
dns3 = Terceiro servidor DNS  
dns4 = Quarto servidor DNS  
criado = Data de criação do domínio  
criadonumero = Número associado ao campo de criação, quando disponível  
alterado = Data da última alteração  
expira = Data de expiração do domínio  



**Exemplo de uso manual**

```bash
/usr/local/bin/zabbix_domain_monitor.sh expira dominio.com.br
```
Exemplo usando o Zabbix Agent:
```bash
zabbix_agentd -t 'domain.whois[expira,dominio.com.br]'
```
Com Zabbix Agent 2:
```bash
zabbix_agent2 -t 'domain.whois[expira,dominio.com.br]'
```

```bash
zabbix-domain-monitor \
├── README.md \
├── install.sh \
├── zabbix_domain_monitor.sh\
├── zabbix_agentd.d/ \
│            └── userparameter_domain.conf \
└── zabbix_template/ \
    └── template_domain_monitor.yaml \
```
