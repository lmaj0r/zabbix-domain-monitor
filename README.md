# zabbix-domain-monitor

Monitoramento de domínios via WHOIS para integração com Zabbix, com cache local, rate limit global e enfileiramento automático de consultas simultâneas.

O projeto foi desenvolvido em **Bash** e utiliza ferramentas nativas do Linux, como `whois` e `flock`, para consultar informações WHOIS de domínios de forma controlada, evitando excesso de requisições, reduzindo risco de bloqueios externos e prevenindo timeouts no Zabbix.

---

## Funcionalidades

- Monitoramento de informações WHOIS de domínios.
- Compatível com domínios `.br` consultados via Registro.br.
- Compatível com diversos domínios internacionais, conforme disponibilidade dos campos WHOIS.
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
- Retorno padronizado como `null` quando uma informação não está disponível.
- Compatível com Zabbix Agent legado.
- Compatível com Zabbix Agent 2.
- Instalador automático.
- Template YAML para importação no Zabbix 7.0.

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
git clone https://github.com/lmaj0r/zabbix-domain-monitor.git
```

Acesse o diretório do projeto:

```bash
cd zabbix-domain-monitor
```

Antes de executar o instalador, aplique permissão de execução ao arquivo:

```bash
sudo chmod +x install.sh
```

Execute o instalador:

```bash
sudo ./install.sh
```

O instalador realiza automaticamente as seguintes ações:

1. Verifica permissões de execução como root.
2. Verifica os arquivos obrigatórios do projeto.
3. Identifica arquivos existentes e pergunta se devem ser atualizados.
4. Verifica dependências obrigatórias.
5. Instala dependências quando possível.
6. Copia o script principal para:

```text
/etc/zabbix/scripts/zabbix_domain_monitor.sh
```

7. Ajusta permissões de execução.
8. Cria o diretório de cache:

```text
/tmp/zabbix_domain_cache
```

9. Ajusta permissões do cache.
10. Copia o arquivo `userparameter_domain.conf` para o diretório do Zabbix Agent ou Zabbix Agent 2.
11. Reinicia o serviço do Zabbix Agent ou Zabbix Agent 2, quando disponível.

---

## Uso manual

O script principal recebe dois parâmetros:

```bash
zabbix_domain_monitor.sh <atributo> <dominio>
```

Exemplo consultando a data de expiração:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh expira empresa.com.br
```

Exemplo consultando o status do domínio:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh status empresa.com.br
```

Exemplo consultando servidores DNS:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh dns1 empresa.com.br
/etc/zabbix/scripts/zabbix_domain_monitor.sh dns2 empresa.com.br
```

Exemplo consultando o proprietário do domínio:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh dono empresa.com.br
```

Quando uma informação não é encontrada, o script retorna:

```text
null
```

---

## Uso com Zabbix Agent

Este projeto utiliza UserParameters no seguinte padrão:

```text
domain.<atributo>[dominio]
```

Exemplos:

```text
domain.expira[empresa.com.br]
domain.status[empresa.com.br]
domain.dono[empresa.com.br]
domain.dns1[empresa.com.br]
```

Teste com Zabbix Agent legado:

```bash
zabbix_agentd -t 'domain.expira[empresa.com.br]'
```

Teste com Zabbix Agent 2:

```bash
zabbix_agent2 -t 'domain.expira[empresa.com.br]'
```

Outros exemplos de teste:

```bash
zabbix_agentd -t 'domain.status[empresa.com.br]'
zabbix_agentd -t 'domain.dns1[empresa.com.br]'
zabbix_agentd -t 'domain.criado[empresa.com.br]'
```

---

## Métricas disponíveis

| Chave Zabbix | Atributo interno | Descrição |
|---|---|---|
| `domain.nome[dominio]` | `nome` | Nome do domínio |
| `domain.status[dominio]` | `status` | Status do domínio |
| `domain.dono[dominio]` | `dono` | Proprietário ou razão social |
| `domain.donocnpj[dominio]` | `donocnpj` | Identificador do proprietário, quando disponível |
| `domain.dononome[dominio]` | `dononome` | Nome do responsável pelo domínio |
| `domain.pais[dominio]` | `pais` | País do registro |
| `domain.donoregistro[dominio]` | `donoregistro` | Código de contato do proprietário |
| `domain.suporteregistro[dominio]` | `suporteregistro` | Código de contato técnico |
| `domain.dns1[dominio]` | `dns1` | Primeiro servidor DNS |
| `domain.dns2[dominio]` | `dns2` | Segundo servidor DNS |
| `domain.dns3[dominio]` | `dns3` | Terceiro servidor DNS |
| `domain.dns4[dominio]` | `dns4` | Quarto servidor DNS |
| `domain.criado[dominio]` | `criado` | Data de criação do domínio |
| `domain.criadonumero[dominio]` | `criadonumero` | Número associado ao campo de criação, quando disponível |
| `domain.alterado[dominio]` | `alterado` | Data da última alteração |
| `domain.expira[dominio]` | `expira` | Data de expiração do domínio |

---

## Campos WHOIS utilizados

O script procura campos comuns em saídas WHOIS do Registro.br e também campos genéricos usados por outros registradores.

Exemplos de campos utilizados para domínios `.br`:

```text
domain
owner
ownerid
responsible
country
owner-c
tech-c
nserver
created
changed
expires
status
```

Exemplos de campos genéricos utilizados como fallback:

```text
Domain Name
Registrant Organization
Registrant Name
Registrant Country
Name Server
Creation Date
Updated Date
Registry Expiry Date
Expiration Date
paid-till
Domain Status
```

A disponibilidade dos dados depende da resposta WHOIS de cada registrador.

---

## Template Zabbix

O template está disponível em:

```text
zabbix_template/template_domain_monitor.yaml
```

Template incluído:

```text
BERNOULLI - Monitor de Dominios
```

Macro principal do domínio:

```text
{$DOMINIO.NOME}
```

Exemplo de valor:

```text
empresa.com.br
```

Macros de alerta de expiração:

| Macro | Valor padrão | Descrição |
|---|---:|---|
| `{$ALERTA.DISATRE.EXPIRACAO}` | `2` | Alerta crítico/desastre para domínios próximos do vencimento |
| `{$ALERTA.EXPIRACAO}` | `30` | Alerta alto para domínios próximos do vencimento |
| `{$ALERTA.INFORMATIVO.EXPIRACAO}` | `60` | Alerta informativo para domínios próximos do vencimento |

> Observação: a macro `{$ALERTA.DISATRE.EXPIRACAO}` foi mantida com esse nome para preservar compatibilidade com o template existente.

---

## Funcionamento do cache

O script utiliza cache local para evitar consultas WHOIS repetidas.

Diretório padrão:

```text
/tmp/zabbix_domain_cache
```

O cache é organizado por TLD.

Exemplo:

```text
/tmp/zabbix_domain_cache/br/empresa.com.br
/tmp/zabbix_domain_cache/com/example.com
```

O TTL padrão do cache é de 5 minutos.

Enquanto o cache estiver válido, novas consultas para o mesmo domínio reutilizam o arquivo local, evitando nova consulta WHOIS externa.

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

Esse controle é global para o script, ou seja, mesmo consultas para domínios diferentes respeitam o intervalo mínimo configurado.

---

## Enfileiramento automático

Quando vários domínios são consultados ao mesmo tempo e o cache está expirado, as consultas são enfileiradas automaticamente com `flock`.

Isso evita:

- Execuções simultâneas descontroladas.
- Sobrecarga no servidor WHOIS.
- Bloqueio por rate limit externo.
- Timeouts em massa no Zabbix Agent.
- Consultas duplicadas para o mesmo domínio.

O script também utiliza lock específico por domínio para impedir que múltiplas execuções atualizem o mesmo cache ao mesmo tempo.

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
- Com labels começando com hífen.
- Com labels terminando com hífen.

Quando o domínio é inválido, o script retorna:

```text
null
```

---

## Timeout de consulta WHOIS

O script utiliza timeout para limitar o tempo de execução da consulta WHOIS quando o comando `timeout` está disponível no sistema.

O tempo padrão configurado no script é de 25 segundos.

Caso o comando `timeout` não esteja disponível, o script executa o `whois` diretamente.

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
  /etc/zabbix/scripts/zabbix_domain_monitor.sh expira "$d" &
done

wait
```

As consultas devem ser serializadas pelo lock global, respeitando o intervalo mínimo de 5 segundos entre execuções WHOIS quando houver necessidade de consulta externa.

Se os domínios já estiverem em cache válido, as respostas poderão retornar rapidamente sem nova consulta WHOIS.

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

Zabbix Agent legado:

```bash
sudo systemctl restart zabbix-agent
```

Zabbix Agent 2:

```bash
sudo systemctl restart zabbix-agent2
```

---

## Remoção manual

Caso seja necessário remover os arquivos instalados manualmente:

```bash
sudo rm -f /etc/zabbix/scripts/zabbix_domain_monitor.sh
sudo rm -f /etc/zabbix/zabbix_agentd.d/userparameter_domain.conf
sudo rm -f /etc/zabbix/zabbix_agent2.d/userparameter_domain.conf
```

Opcionalmente, remova o cache local:

```bash
sudo rm -rf /tmp/zabbix_domain_cache
```

Depois reinicie o agente Zabbix utilizado no ambiente.

---

## Licença

MIT
