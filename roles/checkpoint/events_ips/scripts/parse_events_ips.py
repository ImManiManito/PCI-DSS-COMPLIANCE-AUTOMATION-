#!/usr/bin/env python3
"""Parsea las páginas JSON de Infinity Events (IPS) y genera un CSV de evidencia PCI DSS.

Lee de stdin una página JSON por línea (la salida de checkpoint_events_ips.sh)
y escribe el CSV resultante en stdout. Termina con error si una línea no es JSON
válido, para no generar evidencia incompleta.
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
    "Service",
    "Port",
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


def destination_port(log):
    """En los logs de Check Point 'service' es el puerto destino y 's_port' el puerto origen."""
    service = str(log.get("service", ""))
    if service.isdigit():
        return service
    return get_field(log, "dst_port", "port", "s_port", "Port")


def main():
    writer = csv.writer(sys.stdout)
    writer.writerow(CSV_HEADER)

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
            writer.writerow([
                get_field(log, "time", "Time"),
                get_field(log, "productName", "product", "Cloud Service"),
                get_field(log, "blade", "practice", "product", "Blade/Practice Type"),
                get_field(log, "action", "Action"),
                get_field(log, "severity", "Severity"),
                get_field(log, "src", "source", "Source"),
                get_field(log, "dst", "destination", "Destination"),
                get_field(log, "service_id", "service", "Service"),
                destination_port(log),
            ])
            total += 1

    if total == 0:
        sys.stderr.write("ADVERTENCIA: No se encontraron eventos IPS para el rango solicitado.\n")


if __name__ == "__main__":
    main()
