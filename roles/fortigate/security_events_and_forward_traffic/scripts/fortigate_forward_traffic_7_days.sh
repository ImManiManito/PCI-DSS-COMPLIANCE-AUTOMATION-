#!/usr/bin/env bash
# Logs de tráfico (type=traffic subtype=forward) de los últimos 7 días.
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil weekly, paginado día por día); aquí solo se filtra el tráfico forward.

set -euo pipefail

if [[ $# -ne 7 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>" >&2
    exit 1
fi

DEVICE_NAME="$5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" weekly "$@" \
    | python3 "${SCRIPT_DIR}/parse_forward_traffic.py" "$DEVICE_NAME"
