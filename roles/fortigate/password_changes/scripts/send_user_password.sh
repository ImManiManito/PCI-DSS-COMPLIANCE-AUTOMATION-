#!/usr/bin/env bash
# Envía por correo (sendmail de postfix) el cuerpo recibido por stdin.
# Falla (código != 0) si el mensaje no pudo ser aceptado por postfix.

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Uso: $0 <FROM> <TO> <SUBJECT>  (cuerpo por stdin)" >&2
    exit 1
fi

FROM="$1"; TO="$2"; SUBJECT="$3"

SENDMAIL="$(command -v sendmail || true)"
[[ -n "$SENDMAIL" ]] || SENDMAIL="/usr/sbin/sendmail"
[[ -x "$SENDMAIL" ]] || {
    echo "ERROR: No se encuentra sendmail (postfix)." >&2
    exit 1
}

python3 -c '
import sys
from email.message import EmailMessage
msg = EmailMessage()
msg["From"], msg["To"], msg["Subject"] = sys.argv[1:4]
msg.set_content(sys.stdin.read())
sys.stdout.buffer.write(bytes(msg))
' "$FROM" "$TO" "$SUBJECT" | "$SENDMAIL" -t -oi -f "$FROM"