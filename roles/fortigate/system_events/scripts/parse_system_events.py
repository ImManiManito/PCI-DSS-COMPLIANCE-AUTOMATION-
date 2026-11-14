#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' de FortiGate a un formato legible para evidencia PCI DSS.

System, VPN y User Events. Lo usan el reporte diario (system_events) y el semanal
(system_events_7_days). La entrada mezcla varias consultas, así que se filtra por
subtipo, nivel y rango de fechas (CDMX).
"""
import argparse
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "common"))
from fortigate_logs import (  # noqa: E402
    SEPARATOR, add_range_arguments, event_time, format_time, in_range, is_log_line, parse_line,
)


def format_entry(log, local_dt):
    return (
        f"Fecha (CDMX)   : {format_time(local_dt)}\n"
        f"Subtipo        : {log.get('subtype', 'N/A')}\n"
        f"Nivel          : {log.get('level', 'N/A')}\n"
        f"Descripción    : {log.get('logdesc', 'N/A')}\n"
        f"Usuario        : {log.get('user', 'N/A')}\n"
        f"Alternate User : {log.get('xauthuser', log.get('user', 'N/A'))}\n"
        f"IP origen      : {log.get('srcip', 'N/A')}\n"
        f"IP destino     : {log.get('dstip', 'N/A')}\n"
        f"Remote IP      : {log.get('remip', log.get('peerip', 'N/A'))}\n"
        f"Acción         : {log.get('action', 'N/A')}\n"
        f"Estado         : {log.get('status', 'N/A')}\n"
        f"Mensaje        : {log.get('msg', 'N/A')}\n"
        f"{SEPARATOR}\n\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--subtype", required=True, help="Subtipo permitido (system, vpn, user)")
    parser.add_argument("--levels", required=True, help="Niveles permitidos separados por coma")
    add_range_arguments(parser)
    args = parser.parse_args()
    subtype = args.subtype.lower()
    levels = {lvl.strip().lower() for lvl in args.levels.split(",")}

    found = []
    seen = set()
    for line in sys.stdin.read().splitlines():
        if not is_log_line(line):
            continue
        log = parse_line(line)
        if log.get("subtype", "").lower() != subtype:
            continue
        if log.get("level", "").lower() not in levels:
            continue
        local_dt = event_time(log)
        if not in_range(local_dt, args):
            continue
        # Las consultas de días contiguos pueden traer el mismo registro.
        key = frozenset(log.items())
        if key in seen:
            continue
        seen.add(key)
        found.append((local_dt, log))

    found.sort(key=lambda item: item[0], reverse=True)

    if found:
        sys.stdout.write("".join(format_entry(log, local_dt) for local_dt, log in found))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
