#!/usr/bin/env bash
# Envía por correo (MTA local postfix, comando 'mail') el cuerpo recibido por stdin.

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Uso: $0 <FROM> <TO> <SUBJECT>  (cuerpo por stdin)" >&2
    exit 1
fi

mail -r "$1" -s "$3" "$2"