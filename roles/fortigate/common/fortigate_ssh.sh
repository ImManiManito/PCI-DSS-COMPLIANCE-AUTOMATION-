#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <HOST> <PORT> <USER> <PRIVATE_KEY>" >&2
    exit 1
fi

HOST="$1"
PORT="$2"
USER="$3"
PRIVATE_KEY="$4"

[[ -f "$PRIVATE_KEY" ]] || {
    echo "ERROR: No existe la llave privada: $PRIVATE_KEY" >&2
    exit 1
}

COMMAND_FILE="$(mktemp)"
trap 'rm -f "$COMMAND_FILE"' EXIT

cat > "$COMMAND_FILE"

[[ -s "$COMMAND_FILE" ]] || {
    echo "ERROR: No se recibieron comandos." >&2
    exit 1
}

{
    printf "a\n"
    sleep 1
    cat "$COMMAND_FILE"
    sleep 1
    printf "exit\n"
} | ssh \
    -tt \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=15 \
    -p "$PORT" \
    -i "$PRIVATE_KEY" \
    "$USER@$HOST"