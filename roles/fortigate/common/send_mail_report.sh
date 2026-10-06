#!/usr/bin/env bash
# Envía un correo con archivos de evidencia adjuntos (MIME) usando el sendmail de postfix.
# No depende de la variante de 'mail' instalada (bsd-mailx, mailutils, s-nail).

set -euo pipefail

if [[ $# -lt 4 ]]; then
    echo "Uso: $0 <FROM> <TO> <SUBJECT> <ARCHIVO1> [ARCHIVO2 ...]" >&2
    exit 1
fi

FROM="$1"
TO="$2"
SUBJECT="$3"
shift 3

for file in "$@"; do
    [[ -f "$file" ]] || {
        echo "ERROR: No existe el archivo de evidencia: $file" >&2
        exit 1
    }
done

SENDMAIL="$(command -v sendmail || true)"
[[ -n "$SENDMAIL" ]] || SENDMAIL="/usr/sbin/sendmail"
[[ -x "$SENDMAIL" ]] || {
    echo "ERROR: No se encuentra sendmail (postfix)." >&2
    exit 1
}

python3 - "$FROM" "$TO" "$SUBJECT" "$@" <<'PY' | "$SENDMAIL" -t -oi -f "$FROM"
import mimetypes
import os
import sys
from email.message import EmailMessage

sender, to, subject, *files = sys.argv[1:]
msg = EmailMessage()
msg["From"] = sender
msg["To"] = to
msg["Subject"] = subject
msg.set_content("Se adjunta evidencia PCI DSS generada por Ansible.")
for path in files:
    ctype, _ = mimetypes.guess_type(path)
    maintype, subtype = (ctype or "application/octet-stream").split("/", 1)
    with open(path, "rb") as fh:
        msg.add_attachment(fh.read(), maintype=maintype, subtype=subtype,
                           filename=os.path.basename(path))
sys.stdout.buffer.write(bytes(msg))
PY