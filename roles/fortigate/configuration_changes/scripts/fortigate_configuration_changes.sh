#!/usr/bin/env bash
# Alertamiento-Detección: eventos de cambios de configuración (subtype=system) del día.
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil daily); aquí solo se filtran los registros de configuración.
#
# NOTA: se filtra por subtype "system" y los niveles "information"/"notice", que es
# donde FortiOS registra las entradas de configuración (logid con cfgpath/cfgobj/cfgattr).
# Validar contra la versión de FortiOS del tenant si los niveles de severidad difieren.

set -euo pipefail

if [[ $# -ne 8 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <REPORT_DATE>" >&2
    exit 1
fi

REPORT_DATE="$8"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" daily "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/parse_configuration_changes.py" --date "$REPORT_DATE"
