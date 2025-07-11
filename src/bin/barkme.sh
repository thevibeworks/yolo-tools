#!/bin/bash

# barkme.sh - Send notifications via Bark service
# Usage: barkme.sh [OPTIONS] <message>
# Version: 1.0.0

set -euo pipefail

BARK_SERVER="${BARK_SERVER:-https://api.day.app}"
BARK_KEY="${BARK_KEY:-}"
BARK_GROUP="${BARK_GROUP:-Barkme}"
BARK_SOUND="${BARK_SOUND:-}"
BARK_ICON="${BARK_ICON:-}"
BARK_RETRY="${BARK_RETRY:-1}"

TITLE=""
SUBTITLE=""
BODY=""
SOUND="$BARK_SOUND"
ICON="$BARK_ICON"
GROUP="$BARK_GROUP"
URL=""
LEVEL=""
BADGE=""
COPY=""
AUTOCOPY=""
CALL=""
ARCHIVE=""
VOLUME=""
CIPHERTEXT=""
ACTION=""
DEVICE_KEYS=""
QUIET=false
USE_POST=false
RETRY_COUNT="$BARK_RETRY"

show_help() {
    cat <<EOF
barkme.sh - Send notifications via Bark service

USAGE:
    barkme.sh [OPTIONS] <message>
    echo "message" | barkme.sh [OPTIONS]

CORE OPTIONS (priority order):
    -k, --key <key>         Device key (or set BARK_KEY env var)
    -t, --title <title>     Notification title
    -s, --subtitle <text>   Notification subtitle
    -l, --level <level>     Interruption level (passive|active|timeSensitive|critical)
    -g, --group <group>     Message group (default: Barkme)
    -i, --icon <url>        Custom icon URL
    -u, --url <url>         URL to open when tapped

ADDITIONAL OPTIONS:
    -S, --sound <sound>     Notification sound
    -b, --badge <num>       Badge number
    -c, --copy <text>       Text to copy when notification is tapped
    -C, --autocopy          Auto-copy message content
    -r, --ring              Repeat notification sound (call=1)
    -a, --archive           Save message to history
    -v, --volume <0-10>     Volume for critical alerts (0-10)
    -e, --ciphertext <text> Encrypted message text
    -n, --no-popup          Don't show popup when tapped (action=none)
    -K, --keys <keys>       Comma-separated device keys for batch push

CONTROL OPTIONS:
    -q, --quiet             Quiet mode (minimal output)
    -P, --post              Force JSON POST request (default: GET)
    -R, --retry <count>     Retry count on failure (default: 1)
    -h, --help              Show this help

EXAMPLES:
    barkme.sh "Hello World"
    barkme.sh -t "Alert" -l critical "System down!"
    barkme.sh -t "Deploy" -g "CI/CD" -i "https://example.com/icon.png" "Build completed"
    echo "Build completed" | barkme.sh -q

ENVIRONMENT:
    BARK_SERVER             Bark server URL (default: https://api.day.app)
    BARK_KEY                Device key
    BARK_GROUP              Default group (default: Barkme)
    BARK_SOUND              Default sound
    BARK_ICON               Default icon URL
    BARK_RETRY              Default retry count (default: 1)
EOF
}

urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for ((pos = 0; pos < strlen; pos++)); do
        c=${string:$pos:1}
        case "$c" in
        [-_.~a-zA-Z0-9]) o="${c}" ;;
        *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

get_time_ms() {
    if command -v perl >/dev/null 2>&1; then
        perl -MTime::HiRes -e 'printf "%.3f", Time::HiRes::time()'
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        date +%s.%3N 2>/dev/null || date +%s
    else
        date +%s
    fi
}

send_get() {
    local url="$BARK_SERVER/$BARK_KEY"
    local params=""
    local start_time=$(get_time_ms)

    if [[ -n "$TITLE" && -n "$SUBTITLE" ]]; then
        url+="/$(urlencode "$TITLE")/$(urlencode "$SUBTITLE")/$(urlencode "$BODY")"
    elif [[ -n "$TITLE" ]]; then
        url+="/$(urlencode "$TITLE")/$(urlencode "$BODY")"
    else
        url+="/$(urlencode "$BODY")"
    fi

    [[ -n "$SOUND" ]] && params+="&sound=$SOUND"
    [[ -n "$ICON" ]] && params+="&icon=$(urlencode "$ICON")"
    [[ -n "$GROUP" ]] && params+="&group=$(urlencode "$GROUP")"
    [[ -n "$URL" ]] && params+="&url=$(urlencode "$URL")"
    [[ -n "$LEVEL" ]] && params+="&level=$LEVEL"
    [[ -n "$BADGE" ]] && params+="&badge=$BADGE"
    [[ -n "$COPY" ]] && params+="&copy=$(urlencode "$COPY")"
    [[ -n "$AUTOCOPY" ]] && params+="&autoCopy=1"
    [[ -n "$CALL" ]] && params+="&call=1"
    [[ -n "$ARCHIVE" ]] && params+="&isArchive=1"
    [[ -n "$VOLUME" ]] && params+="&volume=$VOLUME"
    [[ -n "$ACTION" ]] && params+="&action=$ACTION"

    # Remove leading & and add to URL
    params="${params#&}"
    [[ -n "$params" ]] && url+="?$params"

    local attempt=1
    while [[ $attempt -le $RETRY_COUNT ]]; do
        if curl -s --max-time 10 "$url" >/dev/null 2>&1; then
            local end_time=$(get_time_ms)
            local elapsed
            if [[ "$start_time" == *"."* && "$end_time" == *"."* ]]; then
                elapsed=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
            else
                elapsed=$((end_time - start_time))
            fi
            [[ "$QUIET" == "false" ]] && echo "✓ Sent elapsed ${elapsed}s"
            return 0
        fi
        ((attempt++))
        [[ $attempt -le $RETRY_COUNT ]] && sleep 1
    done

    local end_time=$(get_time_ms)
    local elapsed
    if [[ "$start_time" == *"."* && "$end_time" == *"."* ]]; then
        elapsed=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
    else
        elapsed=$((end_time - start_time))
    fi
    [[ "$QUIET" == "false" ]] && echo "✗ Failed after $RETRY_COUNT attempts elapsed ${elapsed}s" >&2
    return 1
}

send_post() {
    local json_data="{"
    json_data+='"body":"'"$(echo "$BODY" | sed 's/"/\\"/g')"'"'
    local start_time=$(get_time_ms)

    [[ -n "$TITLE" ]] && json_data+=', "title":"'"$(echo "$TITLE" | sed 's/"/\\"/g')"'"'
    [[ -n "$SUBTITLE" ]] && json_data+=', "subtitle":"'"$(echo "$SUBTITLE" | sed 's/"/\\"/g')"'"'
    [[ -n "$SOUND" ]] && json_data+=', "sound":"'"$SOUND"'"'
    [[ -n "$ICON" ]] && json_data+=', "icon":"'"$ICON"'"'
    [[ -n "$GROUP" ]] && json_data+=', "group":"'"$GROUP"'"'
    [[ -n "$URL" ]] && json_data+=', "url":"'"$URL"'"'
    [[ -n "$LEVEL" ]] && json_data+=', "level":"'"$LEVEL"'"'
    [[ -n "$BADGE" ]] && json_data+=', "badge":'"$BADGE"
    [[ -n "$COPY" ]] && json_data+=', "copy":"'"$(echo "$COPY" | sed 's/"/\\"/g')"'"'
    [[ -n "$AUTOCOPY" ]] && json_data+=', "autoCopy":"1"'
    [[ -n "$CALL" ]] && json_data+=', "call":"1"'
    [[ -n "$ARCHIVE" ]] && json_data+=', "isArchive":"1"'
    [[ -n "$VOLUME" ]] && json_data+=', "volume":'"$VOLUME"
    [[ -n "$CIPHERTEXT" ]] && json_data+=', "ciphertext":"'"$(echo "$CIPHERTEXT" | sed 's/"/\\"/g')"'"'
    [[ -n "$ACTION" ]] && json_data+=', "action":"'"$ACTION"'"'

    # Handle multiple device keys
    if [[ -n "$DEVICE_KEYS" ]]; then
        local keys_json=""
        IFS=',' read -ra KEYS_ARRAY <<<"$DEVICE_KEYS"
        for key in "${KEYS_ARRAY[@]}"; do
            [[ -n "$keys_json" ]] && keys_json+=", "
            keys_json+="\"$key\""
        done
        json_data+=', "device_keys":['$keys_json']'
    fi

    json_data+="}"

    local attempt=1
    while [[ $attempt -le $RETRY_COUNT ]]; do
        local response
        response=$(curl -s --max-time 10 -X POST "$BARK_SERVER/$BARK_KEY" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d "$json_data" 2>/dev/null)

        if [[ $? -eq 0 ]]; then
            local end_time=$(get_time_ms)
            local elapsed
            if [[ "$start_time" == *"."* && "$end_time" == *"."* ]]; then
                elapsed=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
            else
                elapsed=$((end_time - start_time))
            fi
            if [[ "$QUIET" == "false" ]]; then
                if echo "$response" | grep -q '"code":200'; then
                    echo "✓ Delivered elapsed ${elapsed}s"
                else
                    echo "⚠ Response: $response elapsed ${elapsed}s"
                fi
            fi
            return 0
        fi
        ((attempt++))
        [[ $attempt -le $RETRY_COUNT ]] && sleep 1
    done

    local end_time=$(get_time_ms)
    local elapsed
    if [[ "$start_time" == *"."* && "$end_time" == *"."* ]]; then
        elapsed=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
    else
        elapsed=$((end_time - start_time))
    fi
    [[ "$QUIET" == "false" ]] && echo "✗ Failed after $RETRY_COUNT attempts elapsed ${elapsed}s" >&2
    return 1
}

send_notification() {
    if [[ "$USE_POST" == "true" ]] || [[ -n "$CIPHERTEXT" ]] || [[ -n "$DEVICE_KEYS" ]]; then
        send_post
    else
        send_get
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
    -k | --key)
        BARK_KEY="$2"
        shift 2
        ;;
    -t | --title)
        TITLE="$2"
        shift 2
        ;;
    -s | --subtitle)
        SUBTITLE="$2"
        shift 2
        ;;
    -l | --level)
        if [[ "$2" =~ ^(passive|active|timeSensitive|critical)$ ]]; then
            LEVEL="$2"
        else
            echo "Error: level must be one of: passive, active, timeSensitive, critical" >&2
            exit 1
        fi
        shift 2
        ;;
    -g | --group)
        GROUP="$2"
        shift 2
        ;;
    -i | --icon)
        ICON="$2"
        shift 2
        ;;
    -u | --url)
        URL="$2"
        shift 2
        ;;
    -S | --sound)
        SOUND="$2"
        shift 2
        ;;
    -b | --badge)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            BADGE="$2"
        else
            echo "Error: badge must be a number" >&2
            exit 1
        fi
        shift 2
        ;;
    -c | --copy)
        COPY="$2"
        shift 2
        ;;
    -C | --autocopy)
        AUTOCOPY="1"
        shift
        ;;
    -r | --ring)
        CALL="1"
        shift
        ;;
    -a | --archive)
        ARCHIVE="1"
        shift
        ;;
    -v | --volume)
        if [[ "$2" =~ ^([0-9]|10)$ ]]; then
            VOLUME="$2"
        else
            echo "Error: volume must be 0-10" >&2
            exit 1
        fi
        shift 2
        ;;
    -e | --ciphertext)
        CIPHERTEXT="$2"
        shift 2
        ;;
    -n | --no-popup)
        ACTION="none"
        shift
        ;;
    -K | --keys)
        DEVICE_KEYS="$2"
        shift 2
        ;;
    -q | --quiet)
        QUIET=true
        shift
        ;;
    -P | --post)
        USE_POST=true
        shift
        ;;
    -R | --retry)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            RETRY_COUNT="$2"
        else
            echo "Error: retry count must be a number" >&2
            exit 1
        fi
        shift 2
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    -*)
        echo "Error: Unknown option $1" >&2
        exit 1
        ;;
    *)
        BODY="$1"
        shift
        ;;
    esac
done

# Handle stdin input
if [[ -z "$BODY" ]] && [[ ! -t 0 ]]; then
    BODY=$(cat)
fi

if [[ -z "$BARK_KEY" ]]; then
    [[ "$QUIET" == "false" ]] && echo "Error: Device key required. Set BARK_KEY env var or use -k option" >&2
    exit 1
fi

if [[ -z "$BODY" ]]; then
    [[ "$QUIET" == "false" ]] && echo "Error: Message body required" >&2
    exit 1
fi

send_notification
exit $?
