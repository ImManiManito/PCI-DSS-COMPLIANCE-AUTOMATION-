#!/usr/bin/env python3
"""Parsea alertas de Wazuh filtradas por PCI DSS 10.6.1 (CHD/SAD) y genera un CSV de evidencia.

Columnas: Time, Agent, Rule ID, Level, Description, PCI DSS, Source IP.

Lee de stdin una alerta JSON por línea (salida de chd_sad_review.sh) y escribe
el CSV resultante en stdout.
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
    "Rule ID",
    "Level",
    "Description",
    "PCI DSS",
    "Source IP",
]


def get_field(container, *keys, default="N/A"):
    for key in keys:
        value = container.get(key)
        if value not in (None, ""):
            return value
    return default


def main():
    writer = csv.writer(sys.stdout)
    writer.writerow(CSV_HEADER)

    rows = []  # (hora del evento, fila): se escriben del más reciente al más antiguo

    total = 0
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
        pci_dss = rule.get("pci_dss") or []

        raw_time = get_field(alert, "timestamp", "Time")
        rows.append((event_epoch(raw_time), [
            to_cdmx(raw_time),
            get_field(agent, "name", "id"),
            get_field(rule, "id", "Rule ID"),
            get_field(rule, "level", "Level"),
            get_field(rule, "description", "Description"),
            ", ".join(pci_dss) if pci_dss else "N/A",
            get_field(data, "srcip", "source_ip"),
        ]))
        total += 1

    rows.sort(key=lambda item: item[0], reverse=True)
    writer.writerows(row for _, row in rows)

    if total == 0:
        sys.stderr.write(
            "ADVERTENCIA: No se encontraron eventos CHD/SAD (PCI DSS 10.6.1) para el rango solicitado.\n"
        )


if __name__ == "__main__":
    main()
