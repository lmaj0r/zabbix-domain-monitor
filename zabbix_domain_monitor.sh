#!/usr/bin/env bash

# +===============================================================================+
# |                       ______     _     _     _                                |
# |                      |___  /    | |   | |   (_)                               |
# |                         / / __ _| |__ | |__  ___  __                          |
# |                        / / / _` | '_ \| '_ \| \ \/ /                          |
# |                       / /_| (_| | |_) | |_) | |>  <                           |
# |                      /_____\__,_|_.__/|_.__/|_/_/\_\                          |
# |   _____                        _         __  __             _ _               |
# |  |  __ \                      (_)       |  \/  |           (_) |              |
# |  | |  | | ___  _ __ ___   __ _ _ _ __   | \  / | ___  _ __  _| |_ ___  _ __   |
# |  | |  | |/ _ \| '_ ` _ \ / _` | | '_ \  | |\/| |/ _ \| '_ \| | __/ _ \| '__|  |
# |  | |__| | (_) | | | | | | (_| | | | | | | |  | | (_) | | | | | || (_) | |     |
# |  |_____/ \___/|_| |_| |_|\__,_|_|_| |_| |_|  |_|\___/|_| |_|_|\__\___/|_|     |
# |                                                                 By: maj0r     |
# |                                                                               |
# |                                                                               |
# |                                                                               |
# |                                                                               |
# |Acesse o projeto em https://github.com/lmaj0r/zabbix-domain-monitor            |
# +===============================================================================+

set -o pipefail

CACHE_DIR="${ZBX_DOMAIN_CACHE_DIR:-/var/tmp/zabbix_domain_monitor}"
CACHE_TTL_SECONDS="${ZBX_DOMAIN_CACHE_TTL_SECONDS:-86400}"
WHOIS_TIMEOUT_SECONDS="${ZBX_DOMAIN_WHOIS_TIMEOUT_SECONDS:-20}"
LOCK_TIMEOUT_SECONDS="${ZBX_DOMAIN_LOCK_TIMEOUT_SECONDS:-20}"
RATE_LIMIT_SECONDS="${ZBX_DOMAIN_RATE_LIMIT_SECONDS:-2}"

GLOBAL_LOCK_FILE="${CACHE_DIR}/.global_whois.lock"
LAST_WHOIS_FILE="${CACHE_DIR}/.last_whois"

print_null() {
    echo "null"
}

print_vazio() {
    echo "Vazio"
}

ensure_cache_dir() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 1
    chmod 0755 "$CACHE_DIR" 2>/dev/null || true
    return 0
}

cache_key() {
    local domain="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$domain" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$domain" | sed 's/[^a-zA-Z0-9._-]/_/g'
    fi
}

cache_path() {
    local domain="$1"
    local key

    key="$(cache_key "$domain")"
    printf '%s/%s.whois\n' "$CACHE_DIR" "$key"
}

lock_path() {
    local domain="$1"
    local key

    key="$(cache_key "$domain")"
    printf '%s/%s.lock\n' "$CACHE_DIR" "$key"
}

cache_is_valid() {
    local cache_file="$1"
    local now
    local mtime
    local age

    [ -s "$cache_file" ] || return 1

    now="$(date +%s)"
    mtime="$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)"

    [ "$mtime" -gt 0 ] || return 1

    age=$((now - mtime))

    [ "$age" -lt "$CACHE_TTL_SECONDS" ]
}

normalize_domain() {
    local domain="$1"

    domain="$(printf '%s' "$domain" | tr '[:upper:]' '[:lower:]')"

    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain%%/*}"
    domain="${domain%%\?*}"
    domain="${domain%%:*}"
    domain="${domain%.}"

    domain="$(printf '%s' "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    printf '%s\n' "$domain"
}

is_valid_domain() {
    local domain="$1"

    [[ "$domain" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]
}

is_com_domain() {
    local domain="$1"

    [[ "$domain" =~ \.com$ ]]
}

validate_metric() {
    local metric="$1"

    case "$metric" in
        dados)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

apply_rate_limit_locked() {
    local now
    local last
    local elapsed
    local wait_time

    now="$(date +%s)"
    last="$(cat "$LAST_WHOIS_FILE" 2>/dev/null || echo 0)"

    if ! [[ "$last" =~ ^[0-9]+$ ]]; then
        last=0
    fi

    elapsed=$((now - last))

    if [ "$elapsed" -lt "$RATE_LIMIT_SECONDS" ]; then
        wait_time=$((RATE_LIMIT_SECONDS - elapsed))
        sleep "$wait_time"
    fi

    date +%s > "$LAST_WHOIS_FILE" 2>/dev/null || true
    chmod 0644 "$LAST_WHOIS_FILE" 2>/dev/null || true
}

apply_rate_limit() {
    if command -v flock >/dev/null 2>&1; then
        (
            flock -w "$LOCK_TIMEOUT_SECONDS" 201 2>/dev/null || exit 0
            apply_rate_limit_locked
        ) 201>"$GLOBAL_LOCK_FILE"
    else
        apply_rate_limit_locked
    fi
}

execute_whois() {
    local domain="$1"

    command -v whois >/dev/null 2>&1 || return 127

    if command -v timeout >/dev/null 2>&1; then
        timeout "$WHOIS_TIMEOUT_SECONDS" whois "$domain"
    else
        whois "$domain"
    fi
}

refresh_cache_unlocked() {
    local domain="$1"
    local cache_file
    local tmp_file

    cache_file="$(cache_path "$domain")"

    if cache_is_valid "$cache_file"; then
        return 0
    fi

    tmp_file="$(mktemp "${cache_file}.tmp.XXXXXX" 2>/dev/null)"

    if [ -z "$tmp_file" ]; then
        tmp_file="${cache_file}.tmp.$$"
    fi

    apply_rate_limit

    if execute_whois "$domain" > "$tmp_file" 2>/dev/null && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$cache_file" 2>/dev/null || {
            rm -f "$tmp_file" 2>/dev/null || true
            return 1
        }

        chmod 0644 "$cache_file" 2>/dev/null || true
        return 0
    fi

    rm -f "$tmp_file" 2>/dev/null || true

    if [ -s "$cache_file" ]; then
        return 0
    fi

    return 1
}

refresh_cache() {
    local domain="$1"
    local lock_file

    lock_file="$(lock_path "$domain")"

    if command -v flock >/dev/null 2>&1; then
        (
            flock -w "$LOCK_TIMEOUT_SECONDS" 200 2>/dev/null || exit 1
            refresh_cache_unlocked "$domain"
        ) 200>"$lock_file"
    else
        refresh_cache_unlocked "$domain"
    fi
}

whois_has_domain_data() {
    local cache_file="$1"

    [ -s "$cache_file" ] || return 1

    if grep -Eiq 'no match for|not found|no data found|no entries found|object does not exist|domain not found|status:[[:space:]]*free' "$cache_file"; then
        return 1
    fi

    if grep -Eiq 'rate limit exceeded|query rate limit exceeded|too many requests' "$cache_file"; then
        if ! grep -Eiq '^[[:space:]]*(domain|domain name)[[:space:]]*:' "$cache_file"; then
            return 1
        fi
    fi

    return 0
}

trim() {
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

field_or_vazio() {
    local value="$1"

    if [ -z "$value" ]; then
        print_vazio
    else
        printf '%s\n' "$value"
    fi
}

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"

    printf '%s' "$value"
}

json_string_or_null() {
    local value="$1"

    if [ -z "$value" ] || [ "$value" = "Vazio" ]; then
        printf 'null'
    else
        printf '"%s"' "$(json_escape "$value")"
    fi
}

extract_date_value() {
    local value="$1"

    if [ -z "$value" ]; then
        print_vazio
        return 0
    fi

    if printf '%s' "$value" | grep -Eq '[0-9]{8}'; then
        printf '%s\n' "$value" | grep -Eo '[0-9]{8}' | head -n 1
        return 0
    fi

    if printf '%s' "$value" | grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        printf '%s\n' "$value" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n 1
        return 0
    fi

    printf '%s\n' "$value" | trim
}

extract_created_number() {
    local value="$1"
    local number

    if [ -z "$value" ]; then
        print_vazio
        return 0
    fi

    if printf '%s' "$value" | grep -q '#'; then
        number="$(printf '%s' "$value" | sed 's/^.*#//' | trim)"

        if [ -n "$number" ]; then
            printf '%s\n' "$number"
            return 0
        fi
    fi

    print_vazio
}

get_first_field_value() {
    local file="$1"
    local key="$2"

    awk -v key="$key" '
        BEGIN {
            wanted = tolower(key)
        }

        {
            line = $0
            sub(/\r$/, "", line)

            pos = index(line, ":")
            if (pos <= 0) {
                next
            }

            field = substr(line, 1, pos - 1)
            value = substr(line, pos + 1)

            gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

            if (tolower(field) == wanted && value != "") {
                print value
                exit
            }
        }
    ' "$file"
}

get_first_of_fields() {
    local file="$1"
    shift

    local key
    local value

    for key in "$@"; do
        value="$(get_first_field_value "$file" "$key")"

        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    return 1
}

get_status_values() {
    local file="$1"

    awk '
        {
            line = $0
            sub(/\r$/, "", line)

            pos = index(line, ":")
            if (pos <= 0) {
                next
            }

            field = substr(line, 1, pos - 1)
            value = substr(line, pos + 1)

            gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

            field_lower = tolower(field)

            if ((field_lower == "status" || field_lower == "domain status") && value != "") {
                split(value, parts, /[[:space:]]+/)

                if (field_lower == "domain status") {
                    value = parts[1]
                }

                if (value != "" && !seen[value]++) {
                    if (out == "") {
                        out = value
                    } else {
                        out = out " | " value
                    }
                }
            }
        }

        END {
            if (out != "") {
                print out
            }
        }
    ' "$file"
}

get_name_servers() {
    local file="$1"

    awk '
        {
            line = $0
            sub(/\r$/, "", line)

            pos = index(line, ":")
            if (pos <= 0) {
                next
            }

            field = substr(line, 1, pos - 1)
            value = substr(line, pos + 1)

            gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

            field_lower = tolower(field)

            if (field_lower == "nserver" || field_lower == "name server") {
                split(value, parts, /[[:space:]]+/)
                ns = parts[1]

                gsub(/\.$/, "", ns)

                ns_key = tolower(ns)

                if (ns != "" && !seen[ns_key]++) {
                    print ns
                }
            }
        }
    ' "$file"
}

get_com_domain_data_json() {
    local domain="$1"
    local cache_file="$2"

    local nome
    local dono
    local criado_raw
    local criado
    local alterado_raw
    local alterado
    local expira_raw
    local expira
    local dns1
    local dns2
    local ns_list

    nome="$(get_first_of_fields "$cache_file" "Domain Name")"
    nome="${nome:-$domain}"
    nome="$(printf '%s' "$nome" | tr '[:upper:]' '[:lower:]')"

    dono="$(get_first_of_fields "$cache_file" "Registry Domain ID")"

    alterado_raw="$(get_first_of_fields "$cache_file" "Updated Date")"
    alterado="$(extract_date_value "$alterado_raw")"

    criado_raw="$(get_first_of_fields "$cache_file" "Creation Date")"
    criado="$(extract_date_value "$criado_raw")"

    expira_raw="$(get_first_of_fields "$cache_file" "Registry Expiry Date")"
    expira="$(extract_date_value "$expira_raw")"

    mapfile -t ns_list < <(get_name_servers "$cache_file")

    dns1="${ns_list[0]}"
    dns2="${ns_list[1]}"

    printf '{'
    printf '"nome":'
    json_string_or_null "$nome"
    printf ','
    printf '"status":"Não Suportado",'
    printf '"dono":'
    json_string_or_null "$dono"
    printf ','
    printf '"donocnpj":"Não Suportado",'
    printf '"dononome":"Não Suportado",'
    printf '"pais":"Não Suportado",'
    printf '"donoregistro":"Não Suportado",'
    printf '"suporteregistro":"Não Suportado",'
    printf '"dns1":'
    json_string_or_null "$dns1"
    printf ','
    printf '"dns2":'
    json_string_or_null "$dns2"
    printf ','
    printf '"dns3":null,'
    printf '"dns4":null,'
    printf '"criado":'
    json_string_or_null "$criado"
    printf ','
    printf '"criadonumero":"Não Suportado",'
    printf '"alterado":'
    json_string_or_null "$alterado"
    printf ','
    printf '"expira":'
    json_string_or_null "$expira"
    printf '}\n'
}

get_domain_data_json() {
    local domain="$1"
    local cache_file="$2"

    if is_com_domain "$domain"; then
        get_com_domain_data_json "$domain" "$cache_file"
        return 0
    fi

    local nome
    local status
    local dono
    local donocnpj
    local dononome
    local pais
    local donoregistro
    local suporteregistro
    local dns1
    local dns2
    local dns3
    local dns4
    local criado_raw
    local criado
    local criadonumero
    local alterado_raw
    local alterado
    local expira_raw
    local expira

    local ns_list

    nome="$(get_first_of_fields "$cache_file" "domain" "Domain Name")"
    nome="$(field_or_vazio "${nome:-$domain}")"

    status="$(get_status_values "$cache_file")"
    status="$(field_or_vazio "$status")"

    dono="$(get_first_of_fields "$cache_file" "owner" "Registrant Organization" "Registrant")"
    dono="$(field_or_vazio "$dono")"

    donocnpj="$(get_first_of_fields "$cache_file" "ownerid" "Registry Registrant ID" "Registrant ID")"
    donocnpj="$(field_or_vazio "$donocnpj")"

    dononome="$(get_first_of_fields "$cache_file" "responsible" "Registrant Name")"
    dononome="$(field_or_vazio "$dononome")"

    pais="$(get_first_of_fields "$cache_file" "country" "Registrant Country")"
    pais="$(field_or_vazio "$pais")"

    donoregistro="$(get_first_of_fields "$cache_file" "owner-c" "Registrant Contact")"
    donoregistro="$(field_or_vazio "$donoregistro")"

    suporteregistro="$(get_first_of_fields "$cache_file" "tech-c" "Tech Contact")"
    suporteregistro="$(field_or_vazio "$suporteregistro")"

    mapfile -t ns_list < <(get_name_servers "$cache_file")

    dns1="$(field_or_vazio "${ns_list[0]}")"
    dns2="$(field_or_vazio "${ns_list[1]}")"
    dns3="$(field_or_vazio "${ns_list[2]}")"
    dns4="$(field_or_vazio "${ns_list[3]}")"

    criado_raw="$(get_first_of_fields "$cache_file" "created" "Creation Date" "Created On")"
    criado="$(extract_date_value "$criado_raw")"
    criadonumero="$(extract_created_number "$criado_raw")"

    alterado_raw="$(get_first_of_fields "$cache_file" "changed" "Updated Date" "Last Updated On")"
    alterado="$(extract_date_value "$alterado_raw")"

    expira_raw="$(get_first_of_fields "$cache_file" "expires" "Registry Expiry Date" "Registrar Registration Expiration Date" "Expiration Date")"
    expira="$(extract_date_value "$expira_raw")"

    printf '{'
    printf '"nome":"%s",' "$(json_escape "$nome")"
    printf '"status":"%s",' "$(json_escape "$status")"
    printf '"dono":"%s",' "$(json_escape "$dono")"
    printf '"donocnpj":"%s",' "$(json_escape "$donocnpj")"
    printf '"dononome":"%s",' "$(json_escape "$dononome")"
    printf '"pais":"%s",' "$(json_escape "$pais")"
    printf '"donoregistro":"%s",' "$(json_escape "$donoregistro")"
    printf '"suporteregistro":"%s",' "$(json_escape "$suporteregistro")"
    printf '"dns1":"%s",' "$(json_escape "$dns1")"
    printf '"dns2":"%s",' "$(json_escape "$dns2")"
    printf '"dns3":"%s",' "$(json_escape "$dns3")"
    printf '"dns4":"%s",' "$(json_escape "$dns4")"
    printf '"criado":"%s",' "$(json_escape "$criado")"
    printf '"criadonumero":"%s",' "$(json_escape "$criadonumero")"
    printf '"alterado":"%s",' "$(json_escape "$alterado")"
    printf '"expira":"%s"' "$(json_escape "$expira")"
    printf '}\n'
}

main() {
    local metric="$1"
    local raw_domain="$2"
    local domain
    local cache_file

    if [ -z "$metric" ] || [ -z "$raw_domain" ]; then
        print_null
        return 0
    fi

    if ! validate_metric "$metric"; then
        print_null
        return 0
    fi

    domain="$(normalize_domain "$raw_domain")"

    if [ -z "$domain" ]; then
        print_null
        return 0
    fi

    if ! is_valid_domain "$domain"; then
        print_null
        return 0
    fi

    if ! ensure_cache_dir; then
        print_null
        return 0
    fi

    if ! refresh_cache "$domain"; then
        print_null
        return 0
    fi

    cache_file="$(cache_path "$domain")"

    if ! whois_has_domain_data "$cache_file"; then
        print_null
        return 0
    fi

    get_domain_data_json "$domain" "$cache_file"

    return 0
}

main "$@"
