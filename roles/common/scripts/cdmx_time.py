"""Hora de los eventos (Check Point, Wazuh) para la evidencia: conversión a CDMX y orden.

Los parsers lo importan agregando roles/common/scripts a sys.path.
"""
import re
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

CDMX = ZoneInfo("America/Mexico_City")

# 2026-11-13T06:00:01Z, 2026-11-13T06:00:01.123+0000, 2026-11-13 06:00:01-06:00 ...
ISO_PATTERN = re.compile(
    r"^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(\.\d+)?\s*(Z|[+-]\d{2}:?\d{2})$"
)


def parse_time(value):
    """ISO 8601 con zona (Z u offset) o epoch (s/ms) -> datetime con zona; None si no se reconoce."""
    try:
        if isinstance(value, (int, float)) or (isinstance(value, str) and value.isdigit()):
            seconds = float(value)
            while seconds > 10**11:
                seconds /= 1000
            return datetime.fromtimestamp(seconds, tz=timezone.utc)
        if isinstance(value, str):
            match = ISO_PATTERN.match(value.strip())
            if not match:
                return None
            day, clock, fraction, tz = match.groups()
            tz = "+0000" if tz == "Z" else tz.replace(":", "")
            dt = datetime.strptime(f"{day} {clock} {tz}", "%Y-%m-%d %H:%M:%S %z")
            if fraction:
                dt = dt.replace(microsecond=int(fraction[1:7].ljust(6, "0")))
            return dt
    except (ValueError, OverflowError, OSError):
        return None
    return None


def to_cdmx(value):
    """Devuelve 'YYYY-MM-DD HH:MM:SS CDMX'.

    El sufijo " CDMX" hace que Excel deje el valor como texto: sin él, al abrir el CSV lo
    convierte en fecha y lo muestra como número de serie (46339.9643) o sin segundos.
    Si el valor no trae zona o no se reconoce, se devuelve sin cambios para no inventar
    una hora.
    """
    dt = parse_time(value)
    if dt is None:
        return value
    return dt.astimezone(CDMX).strftime("%Y-%m-%d %H:%M:%S CDMX")


def event_epoch(value):
    """Clave para ordenar del evento más reciente al más antiguo (reverse=True).

    Los valores sin hora reconocible quedan al final del reporte.
    """
    dt = parse_time(value)
    return dt.timestamp() if dt is not None else float("-inf")
