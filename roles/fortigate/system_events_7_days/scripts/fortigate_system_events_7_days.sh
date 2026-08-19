#!/usr/bin/env bash
# Igual a fortigate_system_events.sh pero recorre los últimos 7 días (rolling window).

set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <SUBTYPE>" >&2
    exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PRIVATE_KEY="$4"
SUBTYPE="$5"

# Severidades solicitadas para System, VPN y User Events (PCI DSS - últimos 7 días)
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
    # 0 = hoy, 6 = hace 6 días -> ventana de 7 días
    for day_offset in 0 1 2 3 4 5 6; do
        report_date="$(date -d "-${day_offset} day" +%Y-%m-%d)"
        for severity in "${SEVERITIES[@]}"; do
            echo "execute log filter reset"
            echo "execute log filter category 1"
            echo "execute log filter field subtype ${SUBTYPE}"
            echo "execute log filter field level ${severity}"
            echo "execute log filter field date ${report_date}"
            echo "execute log filter view-lines 1000"
            echo "execute log display"
        done
    done
} > "$COMMANDS_FILE"

bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" < "$COMMANDS_FILE" \
    | python3 "${SCRIPT_DIR}/parse_system_events.py"
