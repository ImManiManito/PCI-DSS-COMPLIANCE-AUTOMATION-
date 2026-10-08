#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 6 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <SUBTYPE> <REPORT_DATE>" >&2
    exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PRIVATE_KEY="$4"
SUBTYPE="$5"
REPORT_DATE="$6"

# Severidades solicitadas para System, VPN y User Events (PCI DSS - últimas 24h)
SEVERITIES=(emergency alert critical error)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/../../common/fortigate_ssh.sh"

[[ -f "$SSH_WRAPPER" ]] || {
    echo "ERROR: No se encuentra el wrapper SSH: $SSH_WRAPPER" >&2
    exit 1
}

COMMANDS_FILE="$(mktemp)"
trap 'rm -f "$COMMANDS_FILE"' EXIT

{
    # Ventana móvil de 24 h: el FortiGate (UTC) filtra por fecha, así que se consultan
    # ayer y hoy (UTC) por severidad y el parser recorta por hora exacta en CDMX.
    for query_date in "$(date -u -d '-1 day' +%Y-%m-%d)" "$(date -u +%Y-%m-%d)"; do
        for severity in "${SEVERITIES[@]}"; do
            echo "execute log filter reset"
            echo "execute log filter category 1"
            echo "execute log filter field subtype ${SUBTYPE}"
            echo "execute log filter field level ${severity}"
            echo "execute log filter field date ${query_date}"
            echo "execute log filter view-lines 1000"
            echo "execute log display"
        done
    done
} > "$COMMANDS_FILE"

LEVELS_CSV="$(IFS=,; echo "${SEVERITIES[*]}")"

bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" < "$COMMANDS_FILE" \
    | python3 "${SCRIPT_DIR}/parse_system_events.py" --hours 24 --levels "$LEVELS_CSV"
