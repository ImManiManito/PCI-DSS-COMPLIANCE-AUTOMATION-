#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' de FortiGate a un formato legible para evidencia PCI DSS."""
import argparse
import re
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

CDMX = ZoneInfo("America/Mexico_City")

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def to_cdmx(log):
    """Devuelve el datetime del log en America/Mexico_City (usa eventtime; si falta, date/time en UTC)."""
    eventtime = log.get("eventtime", "")
    try:
        if eventtime.isdigit():
            seconds = int(eventtime)
            while seconds > 10**11:
                seconds //= 1000
            utc_dt = datetime.fromtimestamp(seconds, tz=timezone.utc)
        else:
            utc_dt = datetime.strptime(
                f"{log['date']} {log['time']}", "%Y-%m-%d %H:%M:%S"
            ).replace(tzinfo=timezone.utc)
    except (KeyError, ValueError):
        return None
    return utc_dt.astimezone(CDMX)


def format_entry(log, local_dt):
    return (
        f"Fecha (CDMX)   : {local_dt.strftime('%Y-%m-%d %H:%M:%S')}\n"
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
    parser.add_argument("--hours", type=int, default=24, help="Ventana en horas hacia atrás desde ahora")
    parser.add_argument("--levels", required=True, help="Niveles permitidos separados por coma")
    args = parser.parse_args()
    levels = {lvl.strip().lower() for lvl in args.levels.split(",")}
    now_cdmx = datetime.now(CDMX)
    window_start = now_cdmx - timedelta(hours=args.hours)

    raw = sys.stdin.read()
    found = []
    seen = set()
    for line in raw.splitlines():
        # Solo procesar líneas de log reales (tienen date= y logid=)
        if "date=" not in line or "logid=" not in line:
            continue
        log = parse_line(line)
        local_dt = to_cdmx(log)
        if local_dt is None or not (window_start <= local_dt <= now_cdmx):
            continue
        if log.get("level", "").lower() not in levels:
            continue
        key = (log.get("eventtime"), log.get("logid"), log.get("msg"))
        if key in seen:
            continue
        seen.add(key)
        found.append((local_dt, log))

    found.sort(key=lambda item: item[0], reverse=True)
    entries = [format_entry(log, local_dt) for local_dt, log in found]

    if entries:
        sys.stdout.write("".join(entries))
    else:
        sys.stdout.write("No se encontraron registros para el filtro aplicado.\n")


if __name__ == "__main__":
    main()
