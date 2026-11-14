#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' filtrando entradas de cambios de configuración.

La entrada mezcla todas las consultas del día (una sola sesión SSH), así que aquí se
aplican los filtros: subtype=system, level=notice/information y el rango de fechas del
reporte (CDMX).
"""
import argparse
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "common"))
from fortigate_logs import (  # noqa: E402
    SEPARATOR, add_range_arguments, event_time, format_time, in_range, is_log_line, parse_line,
)

LEVELS = {"notice", "information"}


def format_entry(log, local_dt):
    return (
        f"Fecha (CDMX)   : {format_time(local_dt)}\n"
        f"Subtipo        : {log.get('subtype', 'N/A')}\n"
        f"Nivel          : {log.get('level', 'N/A')}\n"
        f"Descripción    : {log.get('logdesc', 'N/A')}\n"
        f"Usuario        : {log.get('user', 'N/A')}\n"
        f"Ruta config.   : {log.get('cfgpath', 'N/A')}\n"
        f"Objeto config. : {log.get('cfgobj', 'N/A')}\n"
        f"Atributo       : {log.get('cfgattr', 'N/A')}\n"
        f"Acción         : {log.get('action', 'N/A')}\n"
        f"Mensaje        : {log.get('msg', 'N/A')}\n"
        f"{SEPARATOR}\n\n"
    )


def main():
    parser = argparse.ArgumentParser()
    add_range_arguments(parser)
    args = parser.parse_args()

    found = []
    seen = set()
    for line in sys.stdin.read().splitlines():
        if not is_log_line(line):
            continue
        log = parse_line(line)
        if log.get("subtype", "").lower() != "system":
            continue
        if log.get("level", "").lower() not in LEVELS:
            continue
        local_dt = event_time(log)
        if not in_range(local_dt, args):
            continue
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
