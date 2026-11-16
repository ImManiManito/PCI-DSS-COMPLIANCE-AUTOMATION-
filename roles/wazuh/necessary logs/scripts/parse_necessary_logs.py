#!/usr/bin/env python3
"""Parsea TODAS las alertas de Wazuh (sin filtro) y genera el CSV de evidencia
"Eventos generales de impacto a la seguridad".

Columnas: Time (CDMX), Agent, Agent IP, Rule ID, Level, Description, Groups, PCI DSS,
Source IP, Location.

Lee de stdin una alerta JSON por línea (salida de necessary_logs.sh) y escribe
el CSV resultante en stdout, del evento más reciente al más antiguo.
"""
import csv
import json
import os
import sys

sys.dont_write_bytecode = True  # no dejar __pycache__ en el servidor
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "common", "scripts"))
from cdmx_time import event_epoch, to_cdmx  # noqa: E402

CSV_HEADER = [
    "Time (CDMX)",
    "Agent",
    "Agent IP",
    "Rule ID",
    "Level",
    "Description",
    "Groups",
    "PCI DSS",
    "Source IP",
    "Location",
]


def get_field(container, *keys, default="N/A"):
    for key in keys:
        value = container.get(key)
        if value not in (None, ""):
            return value
    return default


def join_list(value):
    if isinstance(value, list) and value:
        return ", ".join(str(item) for item in value)
    return "N/A"


def main():
    writer = csv.writer(sys.stdout)
    writer.writerow(CSV_HEADER)

    rows = []  # (hora del evento, fila): se escriben del más reciente al más antiguo

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            alert = json.loads(line)
        except json.JSONDecodeError:
            continue

        rule = alert.get("rule", {}) or {}
        agent = alert.get("agent", {}) or {}
        data = alert.get("data", {}) or {}

        raw_time = get_field(alert, "timestamp", "Time")
        rows.append((event_epoch(raw_time), [
            to_cdmx(raw_time),
            get_field(agent, "name", "id"),
            get_field(agent, "ip"),
            get_field(rule, "id", "Rule ID"),
            get_field(rule, "level", "Level"),
            get_field(rule, "description", "Description"),
            join_list(rule.get("groups")),
            join_list(rule.get("pci_dss")),
            get_field(data, "srcip", "source_ip"),
            get_field(alert, "location"),
        ]))

    rows.sort(key=lambda item: item[0], reverse=True)
    writer.writerows(row for _, row in rows)

    if not rows:
        sys.stderr.write("ADVERTENCIA: No se encontraron alertas de Wazuh para el rango solicitado.\n")


if __name__ == "__main__":
    main()
