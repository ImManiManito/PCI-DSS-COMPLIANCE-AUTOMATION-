#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' (type=traffic subtype=forward)
a un formato legible para evidencia PCI DSS, con solo los campos relevantes:
fecha/hora (CDMX), origen, dispositivo, destino, aplicación, resultado, policy id,
servicio, protocolo, puerto origen y puerto destino. Solo incluye el rango del reporte.
"""
import argparse
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "common"))
from fortigate_logs import (  # noqa: E402
    SEPARATOR, add_range_arguments, event_time, format_time, in_range, is_log_line, parse_line,
)

PROTO_NAMES = {
    "1": "ICMP",
    "6": "TCP",
    "17": "UDP",
}


def proto_label(proto):
    return PROTO_NAMES.get(proto, f"Proto {proto}" if proto != "N/A" else "N/A")


def format_entry(log, local_dt, device_name):
    proto = log.get("proto", "N/A")
    return (
        f"Fecha/Hora CDMX : {format_time(local_dt)}\n"
        f"Dispositivo     : {device_name}\n"
        f"Origen          : {log.get('srcip', 'N/A')} (puerto {log.get('srcport', 'N/A')})\n"
        f"Destino         : {log.get('dstip', 'N/A')} (puerto {log.get('dstport', 'N/A')})\n"
        f"Aplicación      : {log.get('app', log.get('service', 'N/A'))}\n"
        f"Resultado       : {log.get('action', 'N/A')}\n"
        f"Policy ID       : {log.get('policyid', 'N/A')}\n"
        f"Servicio        : {log.get('service', 'N/A')}\n"
        f"Protocolo       : {proto_label(proto)}\n"
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
        # Solo procesar líneas de log reales de tráfico forward
        if not is_log_line(line):
            continue
        if 'type="traffic"' not in line or 'subtype="forward"' not in line:
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
