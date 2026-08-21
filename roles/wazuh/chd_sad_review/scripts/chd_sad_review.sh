#!/usr/bin/env bash
# Filtra el archivo alerts.json de Wazuh por regla PCI DSS y rango de fechas,
# volcando cada alerta JSON coincidente (una por línea) a stdout.
#
# El archivo de alertas (/var/ossec/logs/alerts/alerts.json) solo es legible
# por root/ossec; este script se ejecuta con privilegios elevados (become/sudo,
# contraseña almacenada en vault) desde la tarea de Ansible que lo invoca.

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <ALERTS_FILE> <PCI_DSS_REQUIREMENT> <START_TIME_ISO8601> <END_TIME_ISO8601>" >&2
    exit 1
fi

ALERTS_FILE="$1"
PCI_DSS_REQUIREMENT="$2"
START_TIME="$3"
END_TIME="$4"

command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere 'jq'." >&2; exit 1; }

[[ -r "$ALERTS_FILE" ]] || {
    echo "ERROR: No se puede leer el archivo de alertas: $ALERTS_FILE" >&2
    exit 1
}

# alerts.json es un stream de objetos JSON (uno por alerta); jq los procesa
# directamente sin necesidad de que estén separados por comas o en un arreglo.
jq -c \
    --arg req "$PCI_DSS_REQUIREMENT" \
    --arg start "$START_TIME" \
    --arg end "$END_TIME" \
    'select(
        ((.rule.pci_dss? // []) | index($req)) != null
        and (.timestamp >= $start and .timestamp <= $end)
    )' "$ALERTS_FILE"
