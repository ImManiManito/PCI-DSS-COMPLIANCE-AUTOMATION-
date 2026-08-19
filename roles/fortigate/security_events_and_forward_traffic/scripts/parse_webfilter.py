#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' (subtype=webfilter)
a un formato legible para evidencia PCI DSS, con solo los campos relevantes:
fecha/hora, origen, acción, URL, categoría y bytes enviados/recibidos.
"""
import re
import sys

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def format_entry(log, device_name):
    return (
        f"Fecha/Hora      : {log.get('date', 'N/A')} {log.get('time', 'N/A')}\n"
        f"Dispositivo     : {device_name}\n"
        f"Origen          : {log.get('srcip', 'N/A')} (puerto {log.get('srcport', 'N/A')})\n"
        f"Acción          : {log.get('action', 'N/A')}\n"
        f"URL             : {log.get('url', 'N/A')}\n"
        f"Categoría       : {log.get('catdesc', 'N/A')}\n"
        f"Enviado/Recibido: {log.get('sentbyte', 'N/A')} / {log.get('rcvdbyte', 'N/A')} bytes\n"
        f"{SEPARATOR}\n\n"
    )


def main():
    device_name = sys.argv[1] if len(sys.argv) > 1 else "N/A"

    raw = sys.stdin.read()
    seen = set()
    entries = []
    for line in raw.splitlines():
        # Solo procesar líneas de log reales de webfilter
        if "date=" not in line or "logid=" not in line:
            continue
        if 'subtype="webfilter"' not in line:
            continue
        log = parse_line(line)
        # Deduplicar por si las páginas (start=0,1000,...) se solapan
        dedup_key = (log.get("date"), log.get("time"), log.get("sessionid"), log.get("logid"))
        if dedup_key in seen:
            continue
        seen.add(dedup_key)
        entries.append(format_entry(log, device_name))

    if entries:
        sys.stdout.write(f"Total de registros: {len(entries)}\n{SEPARATOR}\n\n")
        sys.stdout.write("".join(entries))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
