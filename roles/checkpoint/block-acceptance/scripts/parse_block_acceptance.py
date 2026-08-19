#!/usr/bin/env python3
"""Parsea las páginas JSON de Infinity Events (todos los logs, sin filtrar) y
genera un CSV de evidencia PCI DSS con las acciones Block/Accept.

Columnas: Time, Cloud Service, Blade/Practice Type, Action, Severity,
Source, Destination, User.

Lee de stdin una página JSON por línea (la salida de checkpoint_block_acceptance.sh)
y escribe el CSV resultante en stdout.
"""
import csv
import json
import sys

CSV_HEADER = [
    "Time",
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
        for key in ("logs", "records", "results", "events"):
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

    total = 0
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            page = json.loads(line)
        except json.JSONDecodeError:
            continue

        for log in extract_logs(page):
            writer.writerow([
                get_field(log, "time", "Time"),
                get_field(log, "productName", "product", "Cloud Service"),
                get_field(log, "blade", "practice", "Blade/Practice Type"),
                # El valor puede venir como "Accept"/"Prevent" (u otras acciones
                # propias de la política) según el blade que generó el log.
                get_field(log, "action", "Action"),
                get_field(log, "severity", "Severity"),
                get_field(log, "src", "source", "Source"),
                get_field(log, "dst", "destination", "Destination"),
                get_field(log, "user", "user_name", "xauthuser", "User"),
            ])
            total += 1

    if total == 0:
        sys.stderr.write("ADVERTENCIA: No se encontraron logs para el rango solicitado.\n")


if __name__ == "__main__":
    main()
