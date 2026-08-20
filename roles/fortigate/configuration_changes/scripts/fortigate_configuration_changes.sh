#!/usr/bin/env bash
# Recolecta eventos de cambios de configuración (subtype=system) vía CLI de FortiGate.
#
# NOTA: se filtra por subtype "system" y los niveles "information"/"notice", que es
# donde FortiOS registra las entradas de configuración (logid con cfgpath/cfgobj/cfgattr).
# Validar contra la versión de FortiOS del tenant si los niveles de severidad difieren.

set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <REPORT_DATE>" >&2
    exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PRIVATE_KEY="$4"
REPORT_DATE="$5"

SEVERITIES=(notice information)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/../../common/fortigate_ssh.sh"

[[ -f "$SSH_WRAPPER" ]] || {
    echo "ERROR: No se encuentra el wrapper SSH: $SSH_WRAPPER" >&2
    exit 1
}

COMMANDS_FILE="$(mktemp)"
trap 'rm -f "$COMMANDS_FILE"' EXIT

{
    for severity in "${SEVERITIES[@]}"; do
        echo "execute log filter reset"
        echo "execute log filter category 1"
        echo "execute log filter field subtype system"
        echo "execute log filter field level ${severity}"
        echo "execute log filter field date ${REPORT_DATE}"
        echo "execute log filter view-lines 1000"
        echo "execute log display"
    done
} > "$COMMANDS_FILE"

bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" < "$COMMANDS_FILE" \
    | python3 "${SCRIPT_DIR}/parse_configuration_changes.py"
