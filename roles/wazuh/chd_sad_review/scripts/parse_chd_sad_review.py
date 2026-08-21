#!/usr/bin/env python3
"""Parsea alertas de Wazuh filtradas por PCI DSS 10.6.1 (CHD/SAD) y genera un CSV de evidencia.

Columnas: Time, Agent, Rule ID, Level, Description, PCI DSS, Source IP.

Lee de stdin una alerta JSON por línea (salida de chd_sad_review.sh) y escribe
el CSV resultante en stdout.
"""
import csv
import json
import sys

CSV_HEADER = [
    "Time",
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

        writer.writerow([
            get_field(alert, "timestamp", "Time"),
            get_field(agent, "name", "id"),
            get_field(rule, "id", "Rule ID"),
            get_field(rule, "level", "Level"),
            get_field(rule, "description", "Description"),
            ", ".join(pci_dss) if pci_dss else "N/A",
            get_field(data, "srcip", "source_ip"),
        ])
        total += 1

    if total == 0:
        sys.stderr.write(
            "ADVERTENCIA: No se encontraron eventos CHD/SAD (PCI DSS 10.6.1) para el rango solicitado.\n"
        )


if __name__ == "__main__":
    main()
