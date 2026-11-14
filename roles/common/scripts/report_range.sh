#!/usr/bin/env bash
# Rango de fechas de un reporte, en hora de CDMX, igual para FortiGate, Check Point y Wazuh.
#
# Rangos (siempre días CDMX ya terminados):
#   <DÍAS>  -> los <DÍAS> días completos anteriores a hoy; 1 (diario) = ayer de 00:00:00
#              a 23:59:59
#   semana  -> la última semana completa de lunes 00:00:00 a domingo 23:59:59. Corriendo
#              el lunes 23 de noviembre (o cualquier día hasta el domingo 29) se obtiene
#              lun 16 a dom 22. Un domingo todavía no terminó, así que corriendo en
#              domingo se obtiene la semana anterior: para incluir el domingo, programar
#              la corrida después de la medianoche del domingo (lunes temprano).
# El rango no depende de la hora de la corrida y las corridas consecutivas quedan
# contiguas, sin huecos ni traslapes.
#
# El servidor está en UTC; cada activo registra la hora a su manera, así que se entregan
# los límites en varios formatos:
#   start_date / end_date   YYYY-MM-DD en CDMX (asunto del correo y encabezados)
#   start / end             ISO 8601 con el offset de CDMX (2026-11-13T00:00:00-06:00)
#   start_utc / end_utc     ISO 8601 en UTC (2026-11-13T06:00:00Z), para la API de Check Point
#   start_epoch / end_epoch segundos Unix, para comparar sin depender de zonas horarias
#
# Uso: report_range.sh <DÍAS|semana>   (imprime un objeto JSON en una línea)

set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^([1-9][0-9]*|semana)$ ]]; then
    echo "Uso: $0 <DÍAS|semana>  (DÍAS: entero mayor que 0)" >&2
    exit 1
fi

MODE="$1"
ZONE="America/Mexico_City"

# Si falta tzdata, 'date' con TZ desconocida calcula en UTC sin avisar: los rangos
# quedarían corridos 6 horas. Mejor fallar.
[[ -f "/usr/share/zoneinfo/${ZONE}" ]] || {
    echo "ERROR: No existe /usr/share/zoneinfo/${ZONE} (instalar el paquete tzdata)." >&2
    exit 1
}

TODAY="$(TZ="$ZONE" date +%F)"
if [[ "$MODE" == "semana" ]]; then
    # Último domingo ya terminado: hoy menos su número de día (lunes=1 ... domingo=7).
    DAYS=7
    END_DATE="$(TZ="$ZONE" date -d "${TODAY} -$(TZ="$ZONE" date -d "$TODAY" +%u) days" +%F)"
    START_DATE="$(TZ="$ZONE" date -d "${END_DATE} -6 days" +%F)"
else
    DAYS="$MODE"
    START_DATE="$(TZ="$ZONE" date -d "${TODAY} -${DAYS} days" +%F)"
    END_DATE="$(TZ="$ZONE" date -d "${TODAY} -1 day" +%F)"
fi

START_EPOCH="$(TZ="$ZONE" date -d "${START_DATE} 00:00:00" +%s)"
END_EPOCH="$(TZ="$ZONE" date -d "${END_DATE} 23:59:59" +%s)"

printf '{"days":%s,"start_date":"%s","end_date":"%s","start":"%s","end":"%s","start_utc":"%s","end_utc":"%s","start_epoch":%s,"end_epoch":%s}\n' \
    "$DAYS" \
    "$START_DATE" \
    "$END_DATE" \
    "$(TZ="$ZONE" date -d "@${START_EPOCH}" +%Y-%m-%dT%H:%M:%S%:z)" \
    "$(TZ="$ZONE" date -d "@${END_EPOCH}" +%Y-%m-%dT%H:%M:%S%:z)" \
    "$(date -u -d "@${START_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)" \
    "$(date -u -d "@${END_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)" \
    "$START_EPOCH" \
    "$END_EPOCH"
