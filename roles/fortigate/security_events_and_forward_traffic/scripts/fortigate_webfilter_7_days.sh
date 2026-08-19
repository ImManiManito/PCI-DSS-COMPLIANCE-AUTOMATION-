#!/usr/bin/env bash
# Recolecta los logs de webfilter (category=3 subtype=webfilter) de los últimos 7 días.
# Se filtra día por día y se pagina con "execute log filter start" para no perder
# registros cuando el total supera el límite de "view-lines" (máx. 1000).

set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE_NAME>" >&2
    exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PRIVATE_KEY="$4"
DEVICE_NAME="$5"

VIEW_LINES=1000
# Páginas por día (start=0,1000,...) con margen suficiente sobre el volumen diario esperado.
PAGE_STARTS=(0 1000 2000)

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
        for page_start in "${PAGE_STARTS[@]}"; do
            echo "execute log filter reset"
            echo "execute log filter category 3"
            echo "execute log filter field subtype webfilter"
            echo "execute log filter field date ${report_date}"
            echo "execute log filter view-lines ${VIEW_LINES}"
            echo "execute log filter start ${page_start}"
            echo "execute log display"
        done
    done
} > "$COMMANDS_FILE"

bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" < "$COMMANDS_FILE" \
    | python3 "${SCRIPT_DIR}/parse_webfilter.py" "$DEVICE_NAME"
