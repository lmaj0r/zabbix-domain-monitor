# zabbix-domain-monitor

Monitoramento de domínios via WHOIS para integração com Zabbix, com cache local, rate limit global e enfileiramento automático de consultas simultâneas.

O projeto foi desenvolvido em **Bash** e utiliza ferramentas nativas do Linux, como `whois` e `flock`, para consultar informações WHOIS de domínios de forma controlada, evitando excesso de requisições e prevenindo timeouts no Zabbix.

---

## Funcionalidades

- Monitoramento de informações WHOIS de domínios.
- Cache local com TTL de 5 minutos.
- Cache armazenado em:

```text
/tmp/zabbix_domain_cache
```

- Organização do cache por TLD.
- Rate limit global de 5 segundos entre consultas WHOIS.
- Enfileiramento automático com `flock`.
- Prevenção de consultas simultâneas para o mesmo domínio.
- Prevenção de timeout ao processar múltiplos domínios simultaneamente.
- Compatível com Zabbix Agent legado.
- Compatível com Zabbix Agent 2.
- Instalador automático.
- Template YAML para importação no Zabbix.

---

## Requisitos

- Linux
- Bash
- `whois`
- `flock`, disponível no pacote `util-linux`
- Zabbix Agent ou Zabbix Agent 2

---

## Instalação

Clone o repositório:

```bash
git clone https://github.com/SEU_USUARIO/zabbix-domain-monitor.git
cd zabbix-domain-monitor
```

Execute o instalador:

```bash
sudo bash install.sh
```

O instalador realiza automaticamente as seguintes ações:

1. Verifica dependências obrigatórias.
2. Instala dependências quando possível.
3. Copia o script principal para:

```text
/usr/local/bin/zabbix_domain_monitor.sh
```

4. Ajusta as permissões de execução.
5. Cria o diretório de cache:

```text
/tmp/zabbix_domain_cache
```

6. Ajusta permissões do cache.
7. Copia o arquivo `userparameter_domain.conf` para o diretório do Zabbix Agent.
8. Reinicia o serviço do Zabbix Agent ou Zabbix Agent 2, quando disponível.

---

## Uso manual

Exemplo de consulta manual:

```bash
/usr/local/bin/zabbix_domain_monitor.sh expira empresa.com.br
```

Exemplo consultando o status do domínio:

```bash
/usr/local/bin/zabbix_domain_monitor.sh status empresa.com.br
```

Exemplo consultando servidores DNS:

```bash
/usr/local/bin/zabbix_domain_monitor.sh dns1 empresa.com.br
/usr/local/bin/zabbix_domain_monitor.sh dns2 empresa.com.br
```

---

## Uso com Zabbix Agent

Teste com Zabbix Agent legado:

```bash
zabbix_agentd -t 'domain.whois[expira,empresa.com.br]'
```

Teste com Zabbix Agent 2:

```bash
zabbix_agent2 -t 'domain.whois[expira,empresa.com.br]'
```

---

## Métricas disponíveis

| Métrica | Descrição |
|---|---|
| `nome` | Nome do domínio |
| `status` | Status do domínio |
| `dono` | Proprietário ou organização responsável |
| `donocnpj` | Identificador do proprietário, quando disponível |
| `dononome` | Nome do responsável pelo domínio |
| `pais` | País do registro |
| `donoregistro` | Código de contato do proprietário |
| `suporteregistro` | Código de contato técnico |
| `dns1` | Primeiro servidor DNS |
| `dns2` | Segundo servidor DNS |
| `dns3` | Terceiro servidor DNS |
| `dns4` | Quarto servidor DNS |
| `criado` | Data de criação do domínio |
| `criadonumero` | Número associado ao campo de criação, quando disponível |
| `alterado` | Data da última alteração |
| `expira` | Data de expiração do domínio |

---

## UserParameter do Zabbix

O item principal utilizado pelo Zabbix é:

```text
domain.whois[atributo,dominio]
```

Exemplo:

```text
domain.whois[expira,empresa.com.br]
```

---

## Funcionamento do cache

O script utiliza cache local para evitar consultas WHOIS repetidas.

Diretório padrão:

```text
/tmp/zabbix_domain_cache
```

O cache é organizado por TLD. Exemplo:

```text
/tmp/zabbix_domain_cache/br/empresa.com.br
/tmp/zabbix_domain_cache/com/example.com
```

O TTL padrão do cache é de 5 minutos.

---

## Rate limit

Para evitar bloqueios por excesso de consultas WHOIS, o projeto aplica um rate limit global de 5 segundos entre consultas.

O controle é feito por lock global em:

```text
/tmp/zabbix_domain_cache/.ratelimit_lock
```

E por controle de tempo em:

```text
/tmp/zabbix_domain_cache/.ratelimit_timer
```

---

## Enfileiramento automático

Quando vários domínios são consultados ao mesmo tempo e o cache está expirado, as consultas são enfileiradas automaticamente com `flock`.

Isso evita:

- Execuções simultâneas descontroladas.
- Sobrecarga no servidor WHOIS.
- Bloqueio por rate limit externo.
- Timeouts em massa no Zabbix Agent.

---

## Validação de domínio

O script valida o domínio antes da consulta.

São rejeitados domínios:

- Vazios.
- Com mais de 253 caracteres.
- Sem ponto.
- Começando com ponto.
- Terminando com ponto.
- Com caracteres inválidos.
- Com labels maiores que 63 caracteres.
- Com labels começando ou terminando com hífen.

---

## Estrutura do repositório

```text
zabbix-domain-monitor/
├── README.md
├── install.sh
├── zabbix_domain_monitor.sh
├── zabbix_agentd.d/
│   └── userparameter_domain.conf
└── zabbix_template/
    └── template_domain_monitor.yaml
```

---

## Arquivos principais

| Arquivo | Descrição |
|---|---|
| `README.md` | Documentação do projeto |
| `install.sh` | Instalador automático |
| `zabbix_domain_monitor.sh` | Script principal de consulta WHOIS |
| `zabbix_agentd.d/userparameter_domain.conf` | Configuração UserParameter do Zabbix |
| `zabbix_template/template_domain_monitor.yaml` | Template para importação no Zabbix |

---

## Teste de concorrência

Para validar o enfileiramento e o rate limit:

```bash
for d in empresa.com.br exemplo.com.br registro.br zabbix.com google.com; do
  /usr/local/bin/zabbix_domain_monitor.sh expira "$d" &
done

wait
```

As consultas devem ser serializadas pelo lock global, respeitando o intervalo mínimo de 5 segundos entre execuções WHOIS.

---

## Observações sobre timeout no Zabbix

Em ambientes com muitos domínios e cache frio, recomenda-se avaliar o parâmetro `Timeout` no Zabbix Agent.

Exemplo:

```ini
Timeout=30
```

Ou, em ambientes maiores:

```ini
Timeout=60
```

Depois de alterar esse parâmetro, reinicie o agente Zabbix.

---

## Licença

MIT
