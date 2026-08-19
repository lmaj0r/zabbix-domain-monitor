#!/usr/bin/env bash

METRIC="${1:-}"
DOMAIN_RAW="${2:-}"

CACHE_DIR="/tmp/zabbix_domain_cache"
CACHE_TTL=300
RATE_LIMIT_SECONDS=5
LOCK_TIMEOUT=60
WHOIS_TIMEOUT=25

GLOBAL_LOCK="${CACHE_DIR}/.ratelimit_lock"
GLOBAL_TIMER="${CACHE_DIR}/.ratelimit_timer"

print_null() {
    echo "null"
}

normalize_domain() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

domain_exists() {
    local domain="$1"
    local label

    [ -n "$domain" ] || return 1
    [ "${#domain}" -le 253 ] || return 1

    [[ "$domain" != .* ]] || return 1
    [[ "$domain" != *. ]] || return 1
    [[ "$domain" == *.* ]] || return 1
    [[ "$domain" =~ ^[a-zA-Z0-9.-]+$ ]] || return 1

    IFS='.' read -r -a labels <<< "$domain"

    for label in "${labels[@]}"; do
        [ -n "$label" ] || return 1
        [ "${#label}" -le 63 ] || return 1
        [[ "$label" != -* ]] || return 1
        [[ "$label" != *- ]] || return 1
    done

    return 0
}

prepare_base_cache() {
    mkdir -p "$CACHE_DIR"
    chmod 1777 "$CACHE_DIR" 2>/dev/null || true

    touch "$GLOBAL_LOCK" "$GLOBAL_TIMER" 2>/dev/null || true
    chmod 666 "$GLOBAL_LOCK" "$GLOBAL_TIMER" 2>/dev/null || true
}

prepare_cache_paths() {
    local domain="$1"
    local tld
    local safe_domain

    tld="${domain##*.}"
    safe_domain="$(echo "$domain" | sed 's/[^a-zA-Z0-9._-]/_/g')"

    TLD_CACHE_DIR="${CACHE_DIR}/${tld}"
    CACHE_FILE="${TLD_CACHE_DIR}/${safe_domain}"
    LOCK_FILE="${TLD_CACHE_DIR}/${safe_domain}.lock"

    mkdir -p "$TLD_CACHE_DIR"
    chmod 1777 "$TLD_CACHE_DIR" 2>/dev/null || true
}

cache_is_valid() {
    [ -s "$CACHE_FILE" ] || return 1

    local now
    local file_mtime
    local age

    now="$(date +%s)"
    file_mtime="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)"
    age=$((now - file_mtime))

    [ "$age" -le "$CACHE_TTL" ]
}

whois_output_is_valid() {
    local file="$1"

    [ -s "$file" ] || return 1

    if grep -Eiq 'timed out|timeout|connection refused|temporary failure|try again|service unavailable|rate limit exceeded|quota exceeded' "$file"; then
        return 1
    fi

    return 0
}

run_whois() {
    local domain="$1"
    local tmp_file="$2"

    if command -v timeout >/dev/null 2>&1; then
        timeout "$WHOIS_TIMEOUT" whois "$domain" > "$tmp_file" 2>/dev/null
    else
        whois "$domain" > "$tmp_file" 2>/dev/null
    fi
}

refresh_cache_if_needed() {
    local domain="$1"
    local last_exec
    local now
    local diff
    local sleep_time
    local tmp_file

    exec 200>"$LOCK_FILE" || return 1

    if ! flock -w "$LOCK_TIMEOUT" 200; then
        return 1
    fi

    if cache_is_valid; then
        flock -u 200
        return 0
    fi

    exec 201>"$GLOBAL_LOCK" || {
        flock -u 200
        return 1
    }

    if ! flock -w "$LOCK_TIMEOUT" 201; then
        flock -u 200
        return 1
    fi

    last_exec="$(cat "$GLOBAL_TIMER" 2>/dev/null || echo 0)"

    if ! [[ "$last_exec" =~ ^[0-9]+$ ]]; then
        last_exec=0
    fi

    now="$(date +%s)"
    diff=$((now - last_exec))

    if [ "$diff" -lt "$RATE_LIMIT_SECONDS" ]; then
        sleep_time=$((RATE_LIMIT_SECONDS - diff))
        sleep "$sleep_time"
    fi

    tmp_file="${CACHE_FILE}.tmp.$$"

    run_whois "$domain" "$tmp_file"

    date +%s > "$GLOBAL_TIMER" 2>/dev/null || true
    chmod 666 "$GLOBAL_TIMER" 2>/dev/null || true

    if whois_output_is_valid "$tmp_file"; then
        mv "$tmp_file" "$CACHE_FILE"
        chmod 666 "$CACHE_FILE" 2>/dev/null || true
    else
        rm -f "$tmp_file"
    fi

    flock -u 201
    flock -u 200

    return 0
}

first_field() {
    local key="$1"
    local file="$2"

    awk -v wanted="$key" '
        BEGIN { IGNORECASE = 1 }
        index($0, ":") > 0 {
            line = $0
            field = line
            sub(/:.*/, "", field)

            if (tolower(field) == tolower(wanted)) {
                sub(/^[^:]*:[ \t]*/, "", line)
                print line
                exit
            }
        }
    ' "$file"
}

last_field() {
    local key="$1"
    local file="$2"

    awk -v wanted="$key" '
        BEGIN { IGNORECASE = 1 }
        index($0, ":") > 0 {
            line = $0
            field = line
            sub(/:.*/, "", field)

            if (tolower(field) == tolower(wanted)) {
                sub(/^[^:]*:[ \t]*/, "", line)
                value = line
            }
        }
        END {
            if (value != "") {
                print value
            }
        }
    ' "$file"
}

nth_field() {
    local key="$1"
    local nth="$2"
    local file="$3"

    awk -v wanted="$key" -v target="$nth" '
        BEGIN {
            IGNORECASE = 1
            count = 0
        }
        index($0, ":") > 0 {
            line = $0
            field = line
            sub(/:.*/, "", field)

            if (tolower(field) == tolower(wanted)) {
                count++
                if (count == target) {
                    sub(/^[^:]*:[ \t]*/, "", line)
                    print line
                    exit
                }
            }
        }
    ' "$file"
}

compact_value() {
    tr -d '[:space:]'
}

return_value_or_null() {
    local value="$1"

    if [ -n "$value" ]; then
        echo "$value"
    else
        print_null
    fi
}

extract_created_number() {
    local value="$1"

    if [[ "$value" == *"#"* ]]; then
        echo "$value" | cut -d'#' -f2 | compact_value
    else
        print_null
    fi
}

get_expiration_value() {
    local file="$1"
    local value

    value="$(first_field "expires" "$file")"

    if [ -z "$value" ]; then
        value="$(first_field "Registry Expiry Date" "$file")"
    fi

    if [ -z "$value" ]; then
        value="$(first_field "Expiration Date" "$file")"
    fi

    if [ -z "$value" ]; then
        value="$(first_field "paid-till" "$file")"
    fi

    echo "$value" | compact_value
}

get_domain_info() {
    local domain="$1"
    local attr="$2"
    local value
    local created_line

    prepare_base_cache
    prepare_cache_paths "$domain"

    if ! cache_is_valid; then
        refresh_cache_if_needed "$domain" >/dev/null 2>&1 || true
    fi

    if [ ! -s "$CACHE_FILE" ]; then
        print_null
        return 0
    fi

    case "$attr" in
        nome)
            value="$(first_field "domain" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Domain Name" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        status)
            value="$(last_field "status" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Domain Status" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dono)
            value="$(first_field "owner" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Registrant Organization" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        donocnpj)
            value="$(first_field "ownerid" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dononome)
            value="$(first_field "responsible" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Registrant Name" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        pais)
            value="$(first_field "country" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Registrant Country" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        donoregistro)
            value="$(first_field "owner-c" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        suporteregistro)
            value="$(first_field "tech-c" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Tech Name" "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dns1)
            value="$(nth_field "nserver" 1 "$CACHE_FILE")"
            [ -z "$value" ] && value="$(nth_field "Name Server" 1 "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dns2)
            value="$(nth_field "nserver" 2 "$CACHE_FILE")"
            [ -z "$value" ] && value="$(nth_field "Name Server" 2 "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dns3)
            value="$(nth_field "nserver" 3 "$CACHE_FILE")"
            [ -z "$value" ] && value="$(nth_field "Name Server" 3 "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        dns4)
            value="$(nth_field "nserver" 4 "$CACHE_FILE")"
            [ -z "$value" ] && value="$(nth_field "Name Server" 4 "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        criado)
            created_line="$(first_field "created" "$CACHE_FILE")"
            [ -z "$created_line" ] && created_line="$(first_field "Creation Date" "$CACHE_FILE")"

            if [ -n "$created_line" ]; then
                echo "$created_line" | cut -d'#' -f1 | compact_value
            else
                print_null
            fi
            ;;

        criadonumero)
            created_line="$(first_field "created" "$CACHE_FILE")"
            extract_created_number "$created_line"
            ;;

        alterado)
            value="$(first_field "changed" "$CACHE_FILE")"
            [ -z "$value" ] && value="$(first_field "Updated Date" "$CACHE_FILE")"

            if [ -n "$value" ]; then
                echo "$value" | compact_value
            else
                print_null
            fi
            ;;

        expira)
            value="$(get_expiration_value "$CACHE_FILE")"
            return_value_or_null "$value"
            ;;

        *)
            print_null
            ;;
    esac
}

check_domain() {
    local attr
    local domain

    attr="$1"
    domain="$(normalize_domain "$2")"

    if [ -z "$attr" ] || [ -z "$domain" ]; then
        print_null
        return 0
    fi

    if ! domain_exists "$domain"; then
        print_null
        return 0
    fi

    get_domain_info "$domain" "$attr"
}

check_domain "$METRIC" "$DOMAIN_RAW"
