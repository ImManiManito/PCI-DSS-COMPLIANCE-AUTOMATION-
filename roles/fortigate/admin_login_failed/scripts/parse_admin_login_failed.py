#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' de FortiGate a un formato legible para evidencia PCI DSS."""
import re
import sys

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')


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
    raw = sys.stdin.read()
    entries = []
    for line in raw.splitlines():
        # Solo procesar líneas de log reales (tienen date= y logid=)
        if "date=" not in line or "logid=" not in line:
            continue
        log = parse_line(line)
        entries.append(format_entry(log))

    if entries:
        sys.stdout.write("".join(entries))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
