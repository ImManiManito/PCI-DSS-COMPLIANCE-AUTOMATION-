#!/usr/bin/env bash
# Todos los logs de Check Point Infinity Events (sin filtrar blade ni acción) del rango
# de fechas recibido (reporte semanal, últimos 7 días).
# La consulta a la API (autenticación, búsqueda por ventanas de 24 horas y paginación)
# está en common/infinity_events_query.sh.
#
# Requiere las variables de entorno CHECKPOINT_CLIENT_ID y CHECKPOINT_ACCESS_KEY.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <AUTH_URL> <EVENTS_URL> <START_TIME_ISO8601> <END_TIME_ISO8601>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/infinity_events_query.sh" "$@" ''
