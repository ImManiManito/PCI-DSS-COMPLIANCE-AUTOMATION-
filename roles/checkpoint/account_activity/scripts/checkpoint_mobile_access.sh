#!/usr/bin/env bash
# Logs del blade Mobile Access (VPN de usuarios) de Check Point Infinity Events del rango
# de fechas recibido.
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

# Mismo campo que las demás consultas (product = columna Blade de Infinity Events). No se
# filtra por acción: el parser elige la última conexión de cada usuario.
bash "${SCRIPT_DIR}/../../common/infinity_events_query.sh" "$@" 'product:"Mobile Access"'
