#!/usr/bin/env bash
# Eventos IPS de Check Point Infinity Events de los últimos 7 días.
# Igual a events_ips/scripts/checkpoint_events_ips.sh; solo cambia el rango de fechas
# que recibe. La consulta a la API (autenticación, búsqueda por ventanas de 24 horas y
# paginación) está en common/infinity_events_query.sh.
#
# Requiere las variables de entorno CHECKPOINT_CLIENT_ID y CHECKPOINT_ACCESS_KEY.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <AUTH_URL> <EVENTS_URL> <START_TIME_ISO8601> <END_TIME_ISO8601>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/infinity_events_query.sh" "$@" 'product:"IPS"'
