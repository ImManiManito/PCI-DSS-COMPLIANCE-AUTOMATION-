#!/usr/bin/env bash
# Agrega a lo acumulado los inicios de sesión en el portal de un FortiGate
# (logdesc "Admin login successful", logs completos; perfil admin_access).

set -euo pipefail

if [[ $# -ne 7 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

umask 077
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Los logs se descargan completos antes de tocar lo acumulado.
bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" admin_access "$@" > "${WORK_DIR}/admin.log"

python3 "${SCRIPT_DIR}/admin_logins.py" update --device "$5" < "${WORK_DIR}/admin.log"
