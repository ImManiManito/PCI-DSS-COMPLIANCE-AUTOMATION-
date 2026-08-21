#!/usr/bin/env bash
# Igual a chd_sad_review.sh pero recorre el histórico de alertas de Wazuh
# (comprimido por día bajo <BASE_DIR>/<YYYY>/<Mon>/) para cubrir los últimos
# N días (rolling window), filtrando por regla PCI DSS y rango de fechas.
#
# Estructura esperada bajo BASE_DIR: <BASE_DIR>/<YYYY>/<Mon>/ossec-alerts-<DD>.json[.gz]
# El día en curso puede no estar comprimido todavía (p.ej. ossec-alerts-21.json).

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Uso: $0 <BASE_DIR> <PCI_DSS_REQUIREMENT> <DAYS_BACK>" >&2
    exit 1
fi

BASE_DIR="$1"
PCI_DSS_REQUIREMENT="$2"
DAYS_BACK="$3"

command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere 'jq'." >&2; exit 1; }

END_DATE="$(date +%Y-%m-%d)"
START_DATE="$(date -d "$((DAYS_BACK - 1)) days ago" +%Y-%m-%d)"
START_TIME="${START_DATE}T00:00:00"
END_TIME="${END_DATE}T23:59:59"

filter_alerts() {
    jq -c \
        --arg req "$PCI_DSS_REQUIREMENT" \
        --arg start "$START_TIME" \
        --arg end "$END_TIME" \
        'select(
            ((.rule.pci_dss? // []) | index($req)) != null
            and (.timestamp >= $start and .timestamp <= $end)
        )'
}

CURRENT_EPOCH="$(date -d "$START_DATE" +%s)"
END_EPOCH="$(date -d "$END_DATE" +%s)"

while [[ "$CURRENT_EPOCH" -le "$END_EPOCH" ]]; do
    CURRENT_DATE="$(date -d "@$CURRENT_EPOCH" +%Y-%m-%d)"
    YEAR="$(date -d "$CURRENT_DATE" +%Y)"
    MONTH_ABBR="$(date -d "$CURRENT_DATE" +%b)"
    DAY="$(date -d "$CURRENT_DATE" +%d)"

    DAY_FILE_GZ="${BASE_DIR}/${YEAR}/${MONTH_ABBR}/ossec-alerts-${DAY}.json.gz"
    DAY_FILE_PLAIN="${BASE_DIR}/${YEAR}/${MONTH_ABBR}/ossec-alerts-${DAY}.json"

    if [[ -r "$DAY_FILE_GZ" ]]; then
        zcat "$DAY_FILE_GZ" | filter_alerts
    elif [[ -r "$DAY_FILE_PLAIN" ]]; then
        filter_alerts < "$DAY_FILE_PLAIN"
    else
        echo "AVISO: No se encontró archivo de alertas para $CURRENT_DATE ($DAY_FILE_GZ / $DAY_FILE_PLAIN)" >&2
    fi

    CURRENT_EPOCH=$(( CURRENT_EPOCH + 86400 ))
done
