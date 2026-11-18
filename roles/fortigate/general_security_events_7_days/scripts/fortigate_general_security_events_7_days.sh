#!/usr/bin/env bash
# Eventos generales de seguridad (subtipo system) de un FortiGate de los últimos 7 días
# completos (CDMX) (reporte trimestral "Logs disponibles 3M").
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil quarterly_events: una sesión SSH propia de este reporte); aquí solo se filtra el
# subtipo system y el rango del reporte.
# El parser es el mismo del reporte diario (system_events/scripts/parse_system_events.py).

set -euo pipefail

if [[ $# -ne 9 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <START_ISO8601> <END_ISO8601>" >&2
    exit 1
fi

START_TIME="$8"
END_TIME="$9"

# Severidades solicitadas para System Events (PCI DSS), las mismas de system_events_7_days.
# Si se cambian, ajustar también EVENT_SEVERITIES en common/fortigate_collect_logs.sh.
LEVELS="emergency,alert,critical,error"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" quarterly_events "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/../../system_events/scripts/parse_system_events.py" \
        --levels "$LEVELS" --subtype system --start "$START_TIME" --end "$END_TIME"
