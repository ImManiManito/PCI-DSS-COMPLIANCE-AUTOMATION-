"""Utilidades compartidas por los parsers de logs de FortiGate ('execute log display').

Todos los reportes se recortan al rango CDMX que calcula roles/common/scripts/report_range.sh
(--start/--end en ISO 8601 con offset) y muestran la fecha de cada evento en hora de CDMX,
sin importar la zona horaria configurada en el FortiGate.
"""
import os
import re
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

CDMX = ZoneInfo("America/Mexico_City")

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')
TZ_PATTERN = re.compile(r"^([+-])(\d{2}):?(\d{2})$")

# Zona del FortiGate solo para logs sin eventtime ni tz (FortiOS muy antiguos).
FALLBACK_DEVICE_TZ = os.environ.get("FORTIGATE_TZ", "UTC")


def is_log_line(line):
    """Solo las líneas de log reales tienen date= y logid=."""
    return "date=" in line and "logid=" in line


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def device_tz(log):
    """Zona del FortiGate según el campo tz del log (p. ej. "-0600")."""
    match = TZ_PATTERN.match(log.get("tz", ""))
    if match:
        sign, hours, minutes = match.groups()
        offset = timedelta(hours=int(hours), minutes=int(minutes))
        return timezone(-offset if sign == "-" else offset)
    return ZoneInfo(FALLBACK_DEVICE_TZ)


def event_time(log):
    """Hora del evento en CDMX, o None si no se puede determinar.

    Usa eventtime (epoch en s, ms, us o ns según la versión de FortiOS), que no depende
    de la zona horaria del equipo. Si falta, usa date/time con el campo tz del log.
    """
    eventtime = log.get("eventtime", "")
    try:
        if eventtime.isdigit():
            seconds = int(eventtime)
            while seconds > 10**11:
                seconds //= 1000
            return datetime.fromtimestamp(seconds, tz=timezone.utc).astimezone(CDMX)
        local = datetime.strptime(f"{log['date']} {log['time']}", "%Y-%m-%d %H:%M:%S")
        return local.replace(tzinfo=device_tz(log)).astimezone(CDMX)
    except (KeyError, ValueError, OverflowError, OSError):
        return None


def format_time(local_dt):
    return local_dt.strftime("%Y-%m-%d %H:%M:%S") if local_dt else "N/A"


def add_range_arguments(parser):
    parser.add_argument("--start", required=True, type=datetime.fromisoformat,
                        help="Inicio del rango, ISO 8601 con offset (incluido)")
    parser.add_argument("--end", required=True, type=datetime.fromisoformat,
                        help="Fin del rango, ISO 8601 con offset (incluido)")


def in_range(local_dt, args):
    return local_dt is not None and args.start <= local_dt <= args.end
