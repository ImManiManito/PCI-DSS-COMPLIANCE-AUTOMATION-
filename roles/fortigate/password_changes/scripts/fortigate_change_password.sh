#!/usr/bin/env bash
# Cambia la contraseña de un usuario local de FortiGate y VERIFICA el cambio comparando el hash
# almacenado (set passwd ENC ...) antes y después. No depende de los mensajes de la CLI.
# La contraseña se recibe por la variable de entorno FORTI_NEW_PASSWD (nunca por argumentos).
# Salida: RESULT=OK | RESULT=FAIL  y  DETAIL=<motivo sin contraseña>

set -uo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY> <TARGET_USER>" >&2
    exit 1
fi

: "${FORTI_NEW_PASSWD:?FORTI_NEW_PASSWD no definida}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/../../common/fortigate_ssh.sh"
HOST="$1"; PORT="$2"; SSH_USER="$3"; KEY="$4"; TARGET="$5"

clean() {
    tr -d '\r' | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -v '^[[:space:]]*$'
}

get_hash() {
    local out
    out="$(
        {
            echo "config user local"
            echo "edit \"${TARGET}\""
            echo "show"
            echo "end"
        } | bash "$SSH_WRAPPER" "$HOST" "$PORT" "$SSH_USER" "$KEY" 2>&1
    )" || true
    printf '%s\n' "$out" | clean \
        | sed -nE 's/^[[:space:]]*set passwd ENC[[:space:]]+([^[:space:]]+).*/\1/p' | tail -n1
}

fail() {
    echo "RESULT=FAIL"
    echo "DETAIL=$1"
    exit 0
}

BEFORE="$(get_hash)"

OUTPUT="$(
    {
        echo "config user local"
        echo "edit \"${TARGET}\""
        echo "set passwd \"${FORTI_NEW_PASSWD}\""
        echo "next"
        echo "end"
    } | bash "$SSH_WRAPPER" "$HOST" "$PORT" "$SSH_USER" "$KEY" 2>&1
)"
RC=$?
CLEAN="$(printf '%s\n' "$OUTPUT" | clean | sed -E 's/ENC [^ ]+/ENC ***/')"
CLEAN="${CLEAN//"$FORTI_NEW_PASSWD"/***}"

AFTER="$(get_hash)"

if [[ -z "$AFTER" ]]; then
    fail "No se pudo leer el hash de la contraseña tras el cambio (rc=${RC}); $(tail -n 4 <<< "$CLEAN" | tr '\n' '|' | cut -c1-300)"
fi
if [[ "$BEFORE" == "$AFTER" ]]; then
    fail "La contraseña NO cambió en FortiGate (hash idéntico, rc=${RC}); $(tail -n 4 <<< "$CLEAN" | tr '\n' '|' | cut -c1-300)"
fi

echo "RESULT=OK"