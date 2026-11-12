#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' filtrando entradas de cambios de configuración.

La entrada mezcla todas las consultas del día (una sola sesión SSH), así que aquí se
aplican los mismos filtros que antes hacía el FortiGate: subtype=system,
level=notice/information y la fecha del reporte.
"""
import argparse
import re
import sys

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')

LEVELS = {"notice", "information"}


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def format_entry(log):
    return (
        f"Fecha          : {log.get('date', 'N/A')} {log.get('time', 'N/A')}\n"
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
        if log.get("subtype", "").lower() != "system":
            continue
        if log.get("level", "").lower() not in LEVELS:
            continue
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
