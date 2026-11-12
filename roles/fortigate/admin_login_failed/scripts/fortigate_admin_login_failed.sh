#!/usr/bin/env bash
# Admin Login Failed (GUI/SSH) del día de un FortiGate.
# Los logs se descargan una sola vez por ejecución (common/fortigate_collect_logs.sh,
# perfil daily); aquí solo se filtran los inicios de sesión fallidos.

set -euo pipefail

if [[ $# -ne 8 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> <REPORT_DATE>" >&2
    exit 1
fi

REPORT_DATE="$8"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" daily "${@:1:7}" \
    | python3 "${SCRIPT_DIR}/parse_admin_login_failed.py" --date "$REPORT_DATE"
