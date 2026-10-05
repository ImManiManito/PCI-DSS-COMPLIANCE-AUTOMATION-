#!/usr/bin/env bash
# Cambia la contraseña de un usuario local de FortiGate.
# La contraseña se recibe por la variable de entorno FORTI_NEW_PASSWD (nunca por argumentos).
# Imprime únicamente RESULT=OK o RESULT=FAIL para no exponer la contraseña en la salida.

set -uo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <TARGET_USER>" >&2
    exit 1
fi

: "${FORTI_NEW_PASSWD:?FORTI_NEW_PASSWD no definida}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/../../common/fortigate_ssh.sh"
TARGET="$5"

OUTPUT="$(
    {
        echo "config user local"
        echo "edit \"${TARGET}\""
        echo "set passwd \"${FORTI_NEW_PASSWD}\""
        echo "next"
        echo "end"
    } | bash "$SSH_WRAPPER" "$1" "$2" "$3" "$4" 2>&1
)"
RC=$?

if [[ $RC -ne 0 ]] || grep -qiE 'command parse error|command fail|unknown action|entry not found|object check operator error|not match|Return code -' <<< "$OUTPUT"; then
    echo "RESULT=FAIL"
    exit 0
fi
echo "RESULT=OK"