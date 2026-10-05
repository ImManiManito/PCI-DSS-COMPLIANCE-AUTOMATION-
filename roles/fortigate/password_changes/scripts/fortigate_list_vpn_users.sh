#!/usr/bin/env bash
# Lista los usuarios locales con acceso VPN (SSL/IPsec) del FortiGate vía CLI y los devuelve como JSON.
# Opcional: exportar VPN_GROUPS_OVERRIDE=grupo1,grupo2 para forzar los grupos de VPN.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/../../common/fortigate_ssh.sh"

[[ -f "$SSH_WRAPPER" ]] || {
    echo "ERROR: No se encuentra el wrapper SSH: $SSH_WRAPPER" >&2
    exit 1
}

{
    echo "config system console"
    echo "set output standard"
    echo "end"
    echo "show user local"
    echo "show user group"
    echo "show vpn ssl settings"
    echo "show vpn ipsec phase1-interface"
    echo "show firewall policy"
} | bash "$SSH_WRAPPER" "$1" "$2" "$3" "$4" \
    | python3 "${SCRIPT_DIR}/parse_vpn_users.py"