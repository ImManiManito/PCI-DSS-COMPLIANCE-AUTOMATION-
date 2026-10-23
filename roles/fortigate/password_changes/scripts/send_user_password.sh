#!/usr/bin/env bash
# Envía por correo (sendmail de postfix) el cuerpo recibido por stdin.
# Falla (código != 0) si el mensaje no pudo ser aceptado por postfix.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <FROM> <TO> <SUBJECT> <SIGNATURE_PNG>  (cuerpo HTML por stdin)" >&2
    exit 1
fi

FROM="$1"; TO="$2"; SUBJECT="$3"; SIGNATURE="$4"

SENDMAIL="$(command -v sendmail || true)"
[[ -n "$SENDMAIL" ]] || SENDMAIL="/usr/sbin/sendmail"
[[ -x "$SENDMAIL" ]] || {
    echo "ERROR: No se encuentra sendmail (postfix)." >&2
    exit 1
}

[[ -r "$SIGNATURE" ]] || {
    echo "ERROR: No se puede leer la imagen de firma: $SIGNATURE" >&2
    exit 1
}

python3 -c '
import sys
from html.parser import HTMLParser
from pathlib import Path
from email.message import EmailMessage

class PlainText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in {"br", "p", "tr", "div"}:
            self.parts.append("\n")

    def handle_data(self, data):
        self.parts.append(data)

msg = EmailMessage()
msg["From"], msg["To"], msg["Subject"] = sys.argv[1:4]
html = sys.stdin.read()
plain = PlainText()
plain.feed(html)
msg.set_content("".join(plain.parts).strip())
msg.add_alternative(html, subtype="html")
msg.get_payload()[-1].add_related(
    Path(sys.argv[4]).read_bytes(),
    maintype="image",
    subtype="png",
    cid="<firma>",
    filename="firma.png",
)
sys.stdout.buffer.write(bytes(msg))
' "$FROM" "$TO" "$SUBJECT" "$SIGNATURE" | "$SENDMAIL" -t -oi -f "$FROM"