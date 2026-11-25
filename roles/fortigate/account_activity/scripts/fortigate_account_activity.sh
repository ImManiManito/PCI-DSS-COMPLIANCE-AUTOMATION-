#!/usr/bin/env bash
# Actualiza el registro de último acceso de los usuarios VPN de un FortiGate.
#   1. Lista los usuarios locales con acceso VPN (mismo script que password_changes).
#   2. Descarga los logs VPN tunnel-up (common/fortigate_collect_logs.sh, perfil vpn_access).
#   3. Sobrescribe el último acceso de cada usuario (vpn_last_access.py).
# La lista de usuarios se consulta en su propia sesión y no pasa por la caché de logs,
# porque 'show user local' incluye los hashes de las contraseñas.

set -euo pipefail

if [[ $# -lt 7 || $# -gt 8 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR> [FECHA_CAMBIO_CONTRASEÑA AAAA-MM-DD]" >&2
    exit 1
fi

DEVICE="$5"
PASSWORD_DATE="${8:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UPDATE_ARGS=(update --device "$DEVICE")
[[ -z "$PASSWORD_DATE" ]] || UPDATE_ARGS+=(--password-date "$PASSWORD_DATE")

umask 077
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

bash "${SCRIPT_DIR}/../../password_changes/scripts/fortigate_list_vpn_users.sh" "${@:1:4}" > "${WORK_DIR}/users.json"
# Los logs se descargan completos antes de tocar el registro.
bash "${SCRIPT_DIR}/../../common/fortigate_collect_logs.sh" vpn_access "${@:1:7}" > "${WORK_DIR}/vpn.log"

python3 "${SCRIPT_DIR}/vpn_last_access.py" "${UPDATE_ARGS[@]}" --users-file "${WORK_DIR}/users.json" < "${WORK_DIR}/vpn.log"
