#!/usr/bin/env bash
# Logs de webfilter (category=3 subtype=webfilter) de la última semana completa (lunes a domingo, CDMX).
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil weekly_traffic, una sesión compartida por forward y webfilter, paginado día por día); aquí solo se filtra webfilter del rango.

set -euo pipefail

if [[ $# -ne 9 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <START_ISO8601> <END_ISO8601>" >&2
    exit 1
fi

DEVICE_NAME="$5"
START_TIME="$8"
END_TIME="$9"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" weekly_traffic "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/parse_webfilter.py" "$DEVICE_NAME" --start "$START_TIME" --end "$END_TIME"
