#!/usr/bin/env bash
# System, VPN y User Events de los últimos 7 días de un FortiGate.
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil weekly); aquí solo se filtra el subtipo pedido.

set -euo pipefail

if [[ $# -ne 8 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <SUBTYPE>" >&2
    exit 1
fi

SUBTYPE="$8"

# Severidades solicitadas para System, VPN y User Events (PCI DSS - últimos 7 días)
LEVELS="emergency,alert,critical,error"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" weekly "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/parse_system_events.py" --levels "$LEVELS" --subtype "$SUBTYPE"
