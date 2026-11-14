#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' (subtype=webfilter)
a un formato legible para evidencia PCI DSS, con solo los campos relevantes:
fecha/hora (CDMX), origen, acción, URL, categoría y bytes enviados/recibidos.
Solo incluye el rango del reporte.
"""
import argparse
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "common"))
from fortigate_logs import (  # noqa: E402
    SEPARATOR, add_range_arguments, event_time, format_time, in_range, is_log_line, parse_line,
)


def format_entry(log, local_dt, device_name):
    return (
        f"Fecha/Hora CDMX : {format_time(local_dt)}\n"
        f"Dispositivo     : {device_name}\n"
        f"Origen          : {log.get('srcip', 'N/A')} (puerto {log.get('srcport', 'N/A')})\n"
        f"Acción          : {log.get('action', 'N/A')}\n"
        f"URL             : {log.get('url', 'N/A')}\n"
        f"Categoría       : {log.get('catdesc', 'N/A')}\n"
        f"Enviado/Recibido: {log.get('sentbyte', 'N/A')} / {log.get('rcvdbyte', 'N/A')} bytes\n"
        f"{SEPARATOR}\n\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("device", nargs="?", default="N/A", help="Nombre del FortiGate")
    add_range_arguments(parser)
    args = parser.parse_args()

    seen = set()
    found = []
    for line in sys.stdin.read().splitlines():
        # Solo procesar líneas de log reales de webfilter
        if not is_log_line(line):
            continue
        if 'subtype="webfilter"' not in line:
            continue
        log = parse_line(line)
        local_dt = event_time(log)
        if not in_range(local_dt, args):
            continue
        # Deduplicar por si las páginas (start=0,1000,...) se solapan
        dedup_key = (log.get("eventtime"), log.get("date"), log.get("time"),
                     log.get("sessionid"), log.get("logid"))
        if dedup_key in seen:
            continue
        seen.add(dedup_key)
        found.append((local_dt, log))

    found.sort(key=lambda item: item[0], reverse=True)

    if found:
        sys.stdout.write(f"Total de registros: {len(found)}\n{SEPARATOR}\n\n")
        sys.stdout.write("".join(format_entry(log, local_dt, args.device) for local_dt, log in found))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
