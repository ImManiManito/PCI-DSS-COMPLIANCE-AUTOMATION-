#!/usr/bin/env python3
"""Parsea las páginas JSON de Infinity Events (VPN/Block) y genera un CSV de evidencia PCI DSS.

Columnas: Time, Cloud Service, Blade/Practice Type, Action, Severity,
Source, Destination, User.

Lee de stdin una página JSON por línea (la salida de checkpoint_auth_failures.sh)
y escribe el CSV resultante en stdout.
"""
import csv
import json
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "common", "scripts"))
from cdmx_time import event_epoch, to_cdmx  # noqa: E402

CSV_HEADER = [
    "Time (CDMX)",
    "Cloud Service",
    "Blade/Practice Type",
    "Action",
    "Severity",
    "Source",
    "Destination",
    "User",
]


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


def main():
    writer = csv.writer(sys.stdout)
    writer.writerow(CSV_HEADER)

    rows = []  # (hora del evento, fila): se escriben del más reciente al más antiguo

    total = 0
    seen = set()
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
            # Las ventanas de búsqueda comparten el instante de corte: descartar repetidos.
            key = json.dumps(log, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            raw_time = get_field(log, "time", "Time")
            rows.append((event_epoch(raw_time), [
                to_cdmx(raw_time),
                get_field(log, "productName", "product", "Cloud Service"),
                get_field(log, "blade", "practice", "product", "Blade/Practice Type"),
                get_field(log, "action", "Action"),
                get_field(log, "severity", "Severity"),
                get_field(log, "src", "source", "Source"),
                get_field(log, "dst", "destination", "Destination"),
                get_field(log, "user", "user_name", "xauthuser", "User"),
            ]))
            total += 1

    rows.sort(key=lambda item: item[0], reverse=True)
    writer.writerows(row for _, row in rows)

    if total == 0:
        sys.stderr.write("ADVERTENCIA: No se encontraron eventos de autenticación para el rango solicitado.\n")


if __name__ == "__main__":
    main()
