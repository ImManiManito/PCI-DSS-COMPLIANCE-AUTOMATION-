#!/usr/bin/env python3
"""Parsea la salida cruda de 'execute log display' (type=traffic subtype=forward)
a un formato legible para evidencia PCI DSS, con solo los campos relevantes:
fecha/hora, origen, dispositivo, destino, aplicación, resultado, policy id,
servicio, protocolo, puerto origen y puerto destino.
"""
import re
import sys

SEPARATOR = "-" * 70

FIELD_PATTERN = re.compile(r'(\w+)=("[^"]*"|\S+)')

PROTO_NAMES = {
    "1": "ICMP",
    "6": "TCP",
    "17": "UDP",
}


def parse_line(line):
    fields = {}
    for key, value in FIELD_PATTERN.findall(line):
        fields[key] = value.strip('"')
    return fields


def proto_label(proto):
    return PROTO_NAMES.get(proto, f"Proto {proto}" if proto != "N/A" else "N/A")


def format_entry(log, device_name):
    proto = log.get("proto", "N/A")
    return (
        f"Fecha/Hora      : {log.get('date', 'N/A')} {log.get('time', 'N/A')}\n"
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
    device_name = sys.argv[1] if len(sys.argv) > 1 else "N/A"

    raw = sys.stdin.read()
    seen = set()
    entries = []
    for line in raw.splitlines():
        # Solo procesar líneas de log reales de tráfico forward
        if "date=" not in line or "logid=" not in line:
            continue
        if 'type="traffic"' not in line or 'subtype="forward"' not in line:
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
