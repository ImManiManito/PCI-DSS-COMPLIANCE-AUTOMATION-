#!/usr/bin/env bash
# Vuelca a stdout TODAS las alertas de Wazuh (sin filtro de requisito, regla ni nivel)
# cuyo timestamp cae dentro del rango solicitado, una alerta JSON por línea. Lo usa el
# reporte semanal "Eventos generales de impacto a la seguridad" (playbooks/weekly/required_logs.yml).
#
# Misma lógica de lectura que roles/wazuh/chd_sad_review/scripts/chd_sad_review.sh:
# Wazuh escribe las alertas del día en curso en <BASE_DIR>/alerts.json y, al cambiar el
# día del servidor (medianoche en SU zona horaria, UTC), las archiva en
# <BASE_DIR>/<YYYY>/<Mon>/ossec-alerts-<DD>.json.gz. El rango es en hora de CDMX y no
# coincide con los días del servidor, así que se leen todos los días del servidor que
# toca el rango y cada alerta se recorta por su hora exacta (timestamp con offset).
#
# Los archivos de alertas solo son legibles por root/wazuh; este script se ejecuta con
# privilegios elevados (become/sudo, contraseña almacenada en vault) desde Ansible.
#
# Uso: necessary_logs.sh <BASE_DIR> <START_ISO8601> <END_ISO8601>

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Uso: $0 <BASE_DIR> <START_TIME_ISO8601> <END_TIME_ISO8601>" >&2
    exit 1
fi

BASE_DIR="${1%/}"
START_TIME="$2"
END_TIME="$3"

command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere 'jq'." >&2; exit 1; }

START_EPOCH="$(date -d "$START_TIME" +%s)" || { echo "ERROR: Fecha de inicio no válida: $START_TIME" >&2; exit 1; }
END_EPOCH="$(date -d "$END_TIME" +%s)" || { echo "ERROR: Fecha de fin no válida: $END_TIME" >&2; exit 1; }
(( START_EPOCH <= END_EPOCH )) || { echo "ERROR: El inicio del rango debe ser anterior al fin." >&2; exit 1; }

filter_alerts() {
    # Sin prefiltro: se procesan todas las alertas; solo se recorta por rango de fechas.
    # -R + fromjson?: una línea incompleta (alerts.json se escribe en vivo) se descarta
    # en lugar de abortar todo el reporte.
    # epoch: "2026-11-13T06:00:01.123+0000" -> segundos Unix, respetando el offset.
    jq -R -c \
        --argjson start "$START_EPOCH" \
        --argjson t_end "$END_EPOCH" \
        'def epoch:
            (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime)
            - ((capture("(?<s>[+-])(?<h>[0-9]{2}):?(?<m>[0-9]{2})$") // {s: "+", h: "00", m: "00"})
               | (if .s == "-" then -1 else 1 end) * ((.h | tonumber) * 3600 + (.m | tonumber) * 60));
        fromjson?
        | select(
            ((.timestamp | type) == "string")
            and ((.timestamp | epoch) as $t | $t >= $start and $t <= $t_end)
        )'
}

# Días del servidor (su zona horaria) que toca el rango. El día en curso todavía está en
# alerts.json; los anteriores, archivados por año/mes (nombre del mes en inglés: LC_ALL=C).
TODAY="$(date +%Y-%m-%d)"
CURRENT_DATE="$(date -d "@${START_EPOCH}" +%Y-%m-%d)"
LAST_DATE="$(date -d "@${END_EPOCH}" +%Y-%m-%d)"
[[ "$LAST_DATE" < "$TODAY" ]] || LAST_DATE="$TODAY"

while [[ ! "$CURRENT_DATE" > "$LAST_DATE" ]]; do
    if [[ "$CURRENT_DATE" == "$TODAY" ]]; then
        CANDIDATES=("${BASE_DIR}/alerts.json")
    else
        ARCHIVE_DIR="${BASE_DIR}/$(LC_ALL=C date -d "$CURRENT_DATE" +%Y/%b)"
        DAY="$(date -d "$CURRENT_DATE" +%d)"
        CANDIDATES=("${ARCHIVE_DIR}/ossec-alerts-${DAY}.json.gz" "${ARCHIVE_DIR}/ossec-alerts-${DAY}.json")
    fi

    FOUND=""
    for file in "${CANDIDATES[@]}"; do
        [[ -r "$file" ]] || continue
        FOUND="$file"
        echo "Procesando ${CURRENT_DATE} (${file})" >&2
        if [[ "$file" == *.gz ]]; then
            zcat "$file" | filter_alerts
        else
            filter_alerts < "$file"
        fi
        break
    done
    [[ -n "$FOUND" ]] || echo "AVISO: No se encontró archivo de alertas para ${CURRENT_DATE} (${CANDIDATES[*]})" >&2

    CURRENT_DATE="$(date -d "${CURRENT_DATE} +1 day" +%Y-%m-%d)"
done
