#!/usr/bin/env bash
# Envía un correo (via el MTA local, comando 'mail') con archivos de evidencia adjuntos.

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Uso: $0 <FROM> <TO> <SUBJECT> <ARCHIVO1> [ARCHIVO2 ...]" >&2
    exit 1
fi

FROM="$1"
TO="$2"
SUBJECT="$3"
shift 3

[[ $# -ge 1 ]] || {
    echo "ERROR: Debe indicar al menos un archivo adjunto." >&2
    exit 1
}

ATTACH_ARGS=()
for file in "$@"; do
    [[ -f "$file" ]] || {
        echo "ERROR: No existe el archivo de evidencia: $file" >&2
        exit 1
    }
    ATTACH_ARGS+=(-a "$file")
done

echo "Se adjunta evidencia PCI DSS generada por Ansible." \
    | mail -r "$FROM" "${ATTACH_ARGS[@]}" -s "$SUBJECT" "$TO"
