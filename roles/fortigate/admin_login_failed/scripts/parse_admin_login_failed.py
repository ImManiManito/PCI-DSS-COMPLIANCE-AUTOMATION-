#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' de FortiGate a un formato legible para evidencia PCI DSS.

La entrada mezcla todas las consultas del día (una sola sesión SSH), así que aquí se
aplican los mismos filtros que antes hacía el FortiGate: subtype=system, level=alert,
action=login, status=failed y la fecha del reporte.
"""
import argparse
import re
import sys

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')

FILTERS = {
    "subtype": "system",
    "level": "alert",
    "action": "login",
    "status": "failed",
}


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def format_entry(log):
    return (
        f"Fecha          : {log.get('date', 'N/A')} {log.get('time', 'N/A')}\n"
        f"Descripción    : {log.get('logdesc', 'N/A')}\n"
        f"Usuario        : {log.get('user', 'N/A')}\n"
        f"Interfaz/UI    : {log.get('ui', 'N/A')}\n"
        f"Método         : {log.get('method', 'N/A')}\n"
        f"IP origen      : {log.get('srcip', 'N/A')}\n"
        f"IP destino     : {log.get('dstip', 'N/A')}\n"
        f"Acción         : {log.get('action', 'N/A')}\n"
        f"Estado         : {log.get('status', 'N/A')}\n"
        f"Razón          : {log.get('reason', 'N/A')}\n"
        f"Mensaje        : {log.get('msg', 'N/A')}\n"
        f"{SEPARATOR}\n\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", required=True, help="Fecha del reporte (YYYY-MM-DD)")
    args = parser.parse_args()

    raw = sys.stdin.read()
    entries = []
    seen = set()
    for line in raw.splitlines():
        # Solo procesar líneas de log reales (tienen date= y logid=)
        if "date=" not in line or "logid=" not in line:
            continue
        log = parse_line(line)
        if log.get("date") != args.date:
            continue
        if any(log.get(field, "").lower() != value for field, value in FILTERS.items()):
            continue
        # El mismo registro también llega en la consulta de System Events: deduplicar.
        key = frozenset(log.items())
        if key in seen:
            continue
        seen.add(key)
        entries.append(format_entry(log))

    if entries:
        sys.stdout.write("".join(entries))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
