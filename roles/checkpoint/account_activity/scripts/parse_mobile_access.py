#!/usr/bin/env python3
"""Última conexión de cada usuario VPN (blade Mobile Access) de Infinity Events, en .txt.

Un renglón por usuario, con su inicio de sesión (Log In) más reciente. Si un usuario no
tiene Log In en el rango, se muestra su evento más reciente que no sea un intento fallido
o bloqueado (el resumen en stderr indica cuántos usuarios están en ese caso).

Columnas: Time, Blade, Source, User.

Lee de stdin una página JSON por línea (la salida de checkpoint_mobile_access.sh) y escribe
la evidencia en stdout. En stderr resume las acciones recibidas.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "common", "scripts"))
from cdmx_time import event_epoch, to_cdmx  # noqa: E402

HEADER = ("Time", "Blade", "Source", "User")
# Acciones que no son una conexión (sin espacios ni guiones, en minúsculas).
FAILED = ("fail", "block", "reject", "drop", "deny", "denied", "prevent")
LINE = "=" * 66


def extract_logs(page):
    """Busca el arreglo de eventos dentro de la respuesta (variantes comunes de la API)."""
    candidates = [page]
    data = page.get("data")
    if isinstance(data, dict):
        candidates.append(data)

    for container in candidates:
        for key in ("records", "logs", "results", "events"):
            value = container.get(key)
            if isinstance(value, list):
                return value
    return []


def get_field(log, *keys, default="N/A"):
    for key in keys:
        value = log.get(key)
        if value not in (None, ""):
            return value
    return default


def normalize(value):
    return re.sub(r"[^a-z]", "", str(value).lower())


def is_failed(log, action):
    texts = (normalize(action), normalize(log.get("auth_status", "")))
    return any(word in text for text in texts for word in FAILED)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--start-date", required=True)
    parser.add_argument("--end-date", required=True)
    args = parser.parse_args()

    # Con LANG=C (cron) la salida con acentos fallaría o saldría ilegible.
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    sys.stdin.reconfigure(encoding="utf-8")

    latest = {}  # usuario -> ((es Log In, hora), fila)
    actions = Counter()
    without_user = 0
    for number, line in enumerate(sys.stdin, start=1):
        line = line.strip()
        if not line:
            continue
        try:
            page = json.loads(line)
        except json.JSONDecodeError:
            sys.exit(f"ERROR: la línea {number} de la respuesta de Infinity Events no es JSON válido.")

        for log in extract_logs(page):
            if not isinstance(log, dict):
                continue
            action = str(get_field(log, "action", "Action"))
            user = str(get_field(log, "user", "user_name", "src_user_name", "xauthuser", "User", default="")).strip()
            actions[action] += 1
            if not user:
                without_user += 1
                continue
            if is_failed(log, action):
                continue
            raw_time = get_field(log, "time", "Time")
            # Un Log In siempre gana a otro tipo de evento; entre iguales, el más reciente.
            rank = (normalize(action) == "login", event_epoch(raw_time))
            key = user.casefold()
            if key not in latest or rank > latest[key][0]:
                latest[key] = (rank, (
                    str(to_cdmx(raw_time)),
                    str(get_field(log, "product", "blade", "practice")),
                    str(get_field(log, "src", "source", "Source")),
                    user,
                ))

    no_login = sum(1 for (is_login, _), _ in latest.values() if not is_login)
    summary = ", ".join(f"{action}={count}" for action, count in actions.most_common())
    print(f"Mobile Access: {sum(actions.values())} logs ({summary or 'ninguno'}); "
          f"{without_user} sin usuario; {len(latest)} usuarios con conexión ({no_login} sin Log In).", file=sys.stderr)
    # 90 días sin una sola conexión apunta a un filtro o campo equivocado: no se envía una
    # evidencia vacía como si nadie se hubiera conectado.
    if not latest:
        sys.exit("ERROR: no se encontró ninguna conexión de usuarios en Mobile Access para el rango solicitado.")

    # La conexión más reciente primero; a igual hora, por usuario.
    rows = [row for _, row in sorted(latest.values(), key=lambda item: (-item[0][1], item[1][-1].casefold()))]
    widths = [max(len(row[i]) for row in [HEADER] + rows) for i in range(len(HEADER))]

    def format_row(row):
        return "  ".join(cell.ljust(width) for cell, width in zip(row, widths)).rstrip()

    now = subprocess.run(["date", "+%Y-%m-%d %H:%M:%S"], env={**os.environ, "TZ": "America/Mexico_City"},
                         capture_output=True, text=True, check=True).stdout.strip()
    print(LINE)
    print("Evidencia PCI DSS - Check Point Últimas conexiones VPN (Mobile Access)")
    print(LINE)
    print(f"Rango cubierto         : {args.start_date} 00:00:00 a {args.end_date} 23:59:59 (CDMX, últimos 3 meses)")
    print(f"Generado el (CDMX)     : {now}")
    print(LINE)
    print()
    print(format_row(HEADER))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print(format_row(row))
    print(f"\nTotal de usuarios: {len(rows)}")


if __name__ == "__main__":
    main()
