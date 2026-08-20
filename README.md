+===============================================================================+
|                       ______     _     _     _                                |
|                      |___  /    | |   | |   (_)                               |
|                         / / __ _| |__ | |__  ___  __                          |
|                        / / / _` | '_ \| '_ \| \ \/ /                          |
|                       / /_| (_| | |_) | |_) | |>  <                           |
|                      /_____\__,_|_.__/|_.__/|_/_/\_\                          |
|   _____                        _         __  __             _ _               |
|  |  __ \                      (_)       |  \/  |           (_) |              |
|  | |  | | ___  _ __ ___   __ _ _ _ __   | \  / | ___  _ __  _| |_ ___  _ __   |
|  | |  | |/ _ \| '_ ` _ \ / _` | | '_ \  | |\/| |/ _ \| '_ \| | __/ _ \| '__|  |
|  | |__| | (_) | | | | | | (_| | | | | | | |  | | (_) | | | | | || (_) | |     |
|  |_____/ \___/|_| |_| |_|\__,_|_|_| |_| |_|  |_|\___/|_| |_|_|\__\___/|_|     |
|                                                                 By: maj0r     |
+===============================================================================+

Monitoramento de domínios via WHOIS para integração com Zabbix, com cache local, rate limit global, controle de concorrência e retorno padronizado em JSON para uso com item master e itens dependentes no Zabbix.

O projeto foi desenvolvido em **Bash** e utiliza ferramentas nativas do Linux, como `whois`, `flock`, `timeout`, `sha256sum`, `awk`, `sed` e `grep`, para consultar informações WHOIS de domínios de forma controlada, reduzindo consultas repetidas, evitando excesso de requisições externas e prevenindo timeouts no Zabbix.

---

## Funcionalidades

- Monitoramento de informações WHOIS de domínios.
- Retorno consolidado em JSON por meio de um item master.
- Compatível com domínios `.br` consultados via Registro.br.
- Compatível com domínios `.com` e diversos domínios internacionais, conforme disponibilidade dos campos WHOIS.
- Cache local com TTL padrão de 24 horas.
- Cache armazenado por padrão em:

```text
/var/tmp/zabbix_domain_monitor
```

- Cache individual por domínio usando hash do nome do domínio.
- Rate limit global entre consultas WHOIS.
- Controle de concorrência com `flock`, quando disponível.
- Prevenção de consultas simultâneas para o mesmo domínio.
- Prevenção de excesso de consultas externas para diferentes domínios.
- Timeout configurável para consultas WHOIS.
- Normalização automática de domínio informado.
- Validação de domínio antes da consulta.
- Retorno padronizado como `null` quando o domínio é inválido, não encontrado ou sem dados válidos.
- Compatível com Zabbix Agent legado.
- Compatível com Zabbix Agent 2.
- Template YAML para importação no Zabbix 7.0.
- Estrutura preparada para item master e itens dependentes.

---

## Requisitos

- Linux
- Bash
- Git
- `whois`
- `flock`, disponível no pacote `util-linux`
- `timeout`, normalmente disponível no pacote `coreutils`
- `sha256sum`, normalmente disponível no pacote `coreutils`
- Zabbix Agent ou Zabbix Agent 2

---

## Instalação

Efetue a instalação no servidor onde está o Zabbix Agent ou Zabbix Agent 2.

Clone o repositório:

```bash
git clone https://github.com/lmaj0r/zabbix-domain-monitor.git
```

Acesse o diretório do projeto:

```bash
cd zabbix-domain-monitor
```

Dê permissão de execução ao instalador:

```bash
sudo chmod +x install.sh
```

Execute o instalador:

```bash
sudo ./install.sh
```

O instalador deve realizar as seguintes ações:

1. Verificar permissões de execução como root.
2. Verificar os arquivos obrigatórios do projeto.
3. Verificar dependências obrigatórias.
4. Instalar dependências quando possível.
5. Copiar o script principal para:

```text
/etc/zabbix/scripts/zabbix_domain_monitor.sh
```

6. Ajustar permissões de execução do script.
7. Copiar o arquivo `userparameter_domain.conf` para o diretório do Zabbix Agent ou Zabbix Agent 2.
8. Reiniciar o serviço do Zabbix Agent ou Zabbix Agent 2, quando disponível.

---

## Arquivo UserParameter

O arquivo de UserParameter utilizado pelo projeto é:

```text
zabbix_agentd.d/userparameter_domain.conf
```

Conteúdo principal:

```ini
UserParameter=domain.dados[*],/usr/bin/env bash /etc/zabbix/scripts/zabbix_domain_monitor.sh dados "\$1"
```

Esse UserParameter cria a chave master:

```text
domain.dados[dominio]
```

Exemplo:

```text
domain.dados[empresa.com.br]
```

O script retorna um JSON com todos os dados disponíveis do domínio. Os demais campos devem ser extraídos no Zabbix por itens dependentes usando JSONPath.

---

## Uso manual

O script principal recebe dois parâmetros:

```bash
zabbix_domain_monitor.sh dados <dominio>
```

Exemplo:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh dados empresa.com.br
```

Exemplo com domínio `.com`:

```bash
/etc/zabbix/scripts/zabbix_domain_monitor.sh dados example.com
```

Quando o domínio é válido e possui dados WHOIS disponíveis, o retorno será um JSON semelhante a:

```json
{
  "nome": "empresa.com.br",
  "status": "published",
  "dono": "Empresa Exemplo LTDA",
  "donocnpj": "00.000.000/0001-00",
  "dononome": "Responsável Técnico",
  "pais": "BR",
  "donoregistro": "ABC123",
  "suporteregistro": "ABC123",
  "dns1": "ns1.empresa.com.br",
  "dns2": "ns2.empresa.com.br",
  "dns3": "Vazio",
  "dns4": "Vazio",
  "criado": "20200101",
  "criadonumero": "12345678",
  "alterado": "20240101",
  "expira": "20270101"
}
```

Quando o domínio é inválido, não encontrado ou não possui dados WHOIS válidos, o script retorna:

```text
null
```

---

## Uso com Zabbix Agent

Este projeto utiliza um item master no seguinte padrão:

```text
domain.dados[dominio]
```

Exemplo:

```text
domain.dados[empresa.com.br]
```

Teste com Zabbix Agent legado:

```bash
zabbix_agentd -t 'domain.dados[empresa.com.br]'
```

Teste com Zabbix Agent 2:

```bash
zabbix_agent2 -t 'domain.dados[empresa.com.br]'
```

Exemplo usando a macro do template:

```bash
zabbix_agent2 -t 'domain.dados[bernoulli.com.br]'
```

---

## Métrica disponível no UserParameter

| Chave Zabbix | Parâmetro interno | Descrição |
|---|---|---|
| `domain.dados[dominio]` | `dados` | Retorna todos os dados WHOIS do domínio em JSON |

---

## Campos retornados no JSON

O item master `domain.dados[dominio]` retorna os seguintes campos:

| Campo JSON | Descrição |
|---|---|
| `nome` | Nome do domínio |
| `status` | Status do domínio |
| `dono` | Proprietário, razão social ou identificador disponível |
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

## Itens dependentes no Zabbix

O template do Zabbix utiliza o item master:

```text
domain.dados[{$DOMINIO.NOME}]
```

A partir dele, os demais campos são extraídos por itens dependentes usando JSONPath.

Exemplos:

| Item dependente | JSONPath |
|---|---|
| `domain.nome[{$DOMINIO.NOME}]` | `$.nome` |
| `domain.status[{$DOMINIO.NOME}]` | `$.status` |
| `domain.dono[{$DOMINIO.NOME}]` | `$.dono` |
| `domain.donocnpj[{$DOMINIO.NOME}]` | `$.donocnpj` |
| `domain.dononome[{$DOMINIO.NOME}]` | `$.dononome` |
| `domain.pais[{$DOMINIO.NOME}]` | `$.pais` |
| `domain.donoregistro[{$DOMINIO.NOME}]` | `$.donoregistro` |
| `domain.suporteregistro[{$DOMINIO.NOME}]` | `$.suporteregistro` |
| `domain.dns1[{$DOMINIO.NOME}]` | `$.dns1` |
| `domain.dns2[{$DOMINIO.NOME}]` | `$.dns2` |
| `domain.dns3[{$DOMINIO.NOME}]` | `$.dns3` |
| `domain.dns4[{$DOMINIO.NOME}]` | `$.dns4` |
| `domain.criado[{$DOMINIO.NOME}]` | `$.criado` |
| `domain.criadonumero[{$DOMINIO.NOME}]` | `$.criadonumero` |
| `domain.alterado[{$DOMINIO.NOME}]` | `$.alterado` |
| `domain.expira[{$DOMINIO.NOME}]` | `$.expira` |

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
Registry Domain ID
Registrant Organization
Registrant
Registrant Name
Registrant Country
Registry Registrant ID
Registrant ID
Registrant Contact
Tech Contact
Name Server
Creation Date
Created On
Updated Date
Last Updated On
Registry Expiry Date
Registrar Registration Expiration Date
Expiration Date
Domain Status
```

A disponibilidade dos dados depende da resposta WHOIS de cada registrador.

---

## Suporte a domínios `.com`

Para domínios `.com`, o script utiliza um tratamento específico.

Campos normalmente extraídos:

| Campo JSON | Origem WHOIS comum |
|---|---|
| `nome` | `Domain Name` |
| `dono` | `Registry Domain ID` |
| `criado` | `Creation Date` |
| `alterado` | `Updated Date` |
| `expira` | `Registry Expiry Date` |
| `dns1` | `Name Server` |
| `dns2` | `Name Server` |

Alguns campos podem retornar `"Não Suportado"` para domínios `.com`, pois nem todos os registradores disponibilizam dados completos de proprietário/responsável na saída WHOIS pública.

Exemplos de campos que podem retornar `"Não Suportado"`:

```text
status
donocnpj
dononome
pais
donoregistro
suporteregistro
criadonumero
```

---

## Template Zabbix

O template do Zabbix está disponível no repositório em:

```text
zabbix_template/template_domain_monitor.yaml
```

Esse arquivo **não precisa ser instalado no servidor do Zabbix Agent**.

Ele deve ser baixado separadamente e importado diretamente pela interface web do Zabbix.

Template incluído:

```text
BERNOULLI - Monitor de Dominios
```

### Como baixar o template

Você pode baixar o arquivo diretamente pelo GitHub:

```text
https://github.com/lmaj0r/zabbix-domain-monitor/blob/main/zabbix_template/template_domain_monitor.yaml
```

Na página do arquivo, clique em:

```text
Download raw file
```

Também é possível baixar via terminal:

```bash
curl -L -o template_domain_monitor.yaml https://raw.githubusercontent.com/lmaj0r/zabbix-domain-monitor/main/zabbix_template/template_domain_monitor.yaml
```

Ou usando `wget`:

```bash
wget -O template_domain_monitor.yaml https://raw.githubusercontent.com/lmaj0r/zabbix-domain-monitor/main/zabbix_template/template_domain_monitor.yaml
```

### Como importar o template no Zabbix

Acesse a interface web do Zabbix e siga o caminho:

```text
Data collection > Templates > Import
```

Em seguida:

1. Selecione o arquivo `template_domain_monitor.yaml`.
2. Clique em `Import`.
3. Após a importação, vincule o template ao host desejado.
4. Configure a macro `{$DOMINIO.NOME}` com o domínio que será monitorado.

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
/var/tmp/zabbix_domain_monitor
```

O cache de cada domínio é salvo em arquivo próprio, usando uma chave baseada em hash SHA-256 do domínio.

Exemplo de arquivo de cache:

```text
/var/tmp/zabbix_domain_monitor/1b9f2c9b6d1f4b7a7d9e9f0d3c2a1b0e.whois
```

O TTL padrão do cache é de 24 horas, equivalente a:

```text
86400 segundos
```

Enquanto o cache estiver válido, novas consultas para o mesmo domínio reutilizam o arquivo local, evitando nova consulta WHOIS externa.

---

## Rate limit

Para evitar bloqueios por excesso de consultas WHOIS, o projeto aplica um rate limit global entre consultas externas.

Valor padrão:

```text
2 segundos
```

O controle global utiliza os seguintes arquivos:

```text
/var/tmp/zabbix_domain_monitor/.global_whois.lock
/var/tmp/zabbix_domain_monitor/.last_whois
```

Esse controle é global para o script. Ou seja, mesmo consultas para domínios diferentes respeitam o intervalo mínimo configurado quando houver necessidade de executar nova consulta WHOIS externa.

---

## Enfileiramento automático

Quando vários domínios são consultados ao mesmo tempo e o cache está expirado, as consultas são controladas automaticamente com `flock`, quando disponível.

Isso evita:

- Execuções simultâneas descontroladas.
- Sobrecarga no servidor WHOIS.
- Bloqueio por rate limit externo.
- Timeouts em massa no Zabbix Agent.
- Consultas duplicadas para o mesmo domínio.
- Atualização simultânea do mesmo arquivo de cache.

O script utiliza dois níveis de controle:

1. Lock global para rate limit entre consultas WHOIS.
2. Lock específico por domínio para impedir múltiplas atualizações simultâneas do mesmo cache.

---

## Validação e normalização de domínio

Antes da consulta, o domínio informado é normalizado.

Exemplos de entradas aceitas:

```text
https://empresa.com.br
http://empresa.com.br
empresa.com.br/
empresa.com.br:443
EMPRESA.COM.BR
```

Após normalização:

```text
empresa.com.br
```

O script rejeita domínios:

- Vazios.
- Sem ponto.
- Com caracteres inválidos.
- Com labels maiores que 63 caracteres.
- Com labels começando com hífen.
- Com labels terminando com hífen.
- Fora do padrão esperado para nomes de domínio.

Quando o domínio é inválido, o script retorna:

```text
null
```

---

## Timeout de consulta WHOIS

O script utiliza timeout para limitar o tempo de execução da consulta WHOIS quando o comando `timeout` está disponível no sistema.

Tempo padrão:

```text
20 segundos
```

Caso o comando `timeout` não esteja disponível, o script executa o `whois` diretamente.

---

## Variáveis de ambiente

O comportamento do script pode ser ajustado por variáveis de ambiente.

| Variável | Valor padrão | Descrição |
|---|---:|---|
| `ZBX_DOMAIN_CACHE_DIR` | `/var/tmp/zabbix_domain_monitor` | Diretório de cache |
| `ZBX_DOMAIN_CACHE_TTL_SECONDS` | `86400` | TTL do cache em segundos |
| `ZBX_DOMAIN_WHOIS_TIMEOUT_SECONDS` | `20` | Timeout da consulta WHOIS |
| `ZBX_DOMAIN_LOCK_TIMEOUT_SECONDS` | `20` | Tempo máximo de espera por lock |
| `ZBX_DOMAIN_RATE_LIMIT_SECONDS` | `2` | Intervalo mínimo entre consultas WHOIS externas |

Exemplo de execução manual alterando o TTL do cache para 5 minutos:

```bash
ZBX_DOMAIN_CACHE_TTL_SECONDS=300 /etc/zabbix/scripts/zabbix_domain_monitor.sh dados empresa.com.br
```

Exemplo alterando o diretório de cache:

```bash
ZBX_DOMAIN_CACHE_DIR=/tmp/zabbix_domain_cache /etc/zabbix/scripts/zabbix_domain_monitor.sh dados empresa.com.br
```

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
| `zabbix_template/template_domain_monitor.yaml` | Template para importação manual no Zabbix |

---

## Teste de concorrência

Para validar o enfileiramento, o cache e o rate limit:

```bash
for d in empresa.com.br exemplo.com.br registro.br zabbix.com google.com; do
  /etc/zabbix/scripts/zabbix_domain_monitor.sh dados "$d" &
done

wait
```

As consultas externas devem respeitar o lock global e o intervalo mínimo configurado.

Se os domínios já estiverem em cache válido, as respostas poderão retornar rapidamente sem nova consulta WHOIS.

---

## Teste pelo Zabbix Agent

Zabbix Agent legado:

```bash
zabbix_agentd -t 'domain.dados[empresa.com.br]'
```

Zabbix Agent 2:

```bash
zabbix_agent2 -t 'domain.dados[empresa.com.br]'
```

O retorno esperado é semelhante a:

```text
domain.dados[empresa.com.br] [t|{"nome":"empresa.com.br","status":"published","dono":"...","donocnpj":"...","dononome":"...","pais":"BR","donoregistro":"...","suporteregistro":"...","dns1":"...","dns2":"...","dns3":"Vazio","dns4":"Vazio","criado":"20200101","criadonumero":"...","alterado":"20240101","expira":"20270101"}]
```

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
sudo rm -rf /var/tmp/zabbix_domain_monitor
```

Depois reinicie o agente Zabbix utilizado no ambiente.

Zabbix Agent legado:

```bash
sudo systemctl restart zabbix-agent
```

Zabbix Agent 2:

```bash
sudo systemctl restart zabbix-agent2
```

---

## Licença

MIT
