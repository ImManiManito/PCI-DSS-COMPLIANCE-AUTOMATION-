#!/usr/bin/env bash
# System, VPN y User Events de un FortiGate del día CDMX anterior (reporte diario).
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil daily); aquí solo se filtra el subtipo pedido y el rango del reporte.

set -euo pipefail

if [[ $# -ne 10 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <SUBTYPE> <START_ISO8601> <END_ISO8601>" >&2
    exit 1
fi

SUBTYPE="$8"
START_TIME="$9"
END_TIME="${10}"

# Severidades solicitadas para System, VPN y User Events (PCI DSS). Si se cambian,
# ajustar también EVENT_SEVERITIES en common/fortigate_collect_logs.sh.
LEVELS="emergency,alert,critical,error"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" daily "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/parse_system_events.py" \
        --levels "$LEVELS" --subtype "$SUBTYPE" --start "$START_TIME" --end "$END_TIME"
