#!/usr/bin/env bash
# Descarga en UNA sola sesión SSH por FortiGate y por perfil todos los logs que necesita
# ese perfil y los guarda en caché. Los roles que comparten perfil reutilizan esa caché
# en lugar de volver a iniciar sesión en el equipo.
#
# Perfiles (rangos en hora de CDMX, ver roles/common/scripts/report_range.sh):
#   daily          -> 1 sesión para todos los diarios: System/VPN/User Events,
#                     Admin Login Failed y Alertamiento-Detección (ayer)
#   weekly_events  -> 1 sesión para system_events_7_days: System/VPN/User Events
#                     (semana de lunes a domingo)
#   quarterly_events -> 1 sesión para general_security_events_7_days (Logs disponibles 3M):
#                     solo System Events de los últimos 7 días completos
#   weekly_traffic -> 1 sesión para security_events_and_forward_traffic: Forward Traffic
#                     y Webfilter (semana de lunes a domingo)
#
# El FortiGate filtra por la fecha de SU zona horaria, que puede no ser la de CDMX
# (p. ej. UTC: el día CDMX va de 06:00 de ese día a 05:59 del siguiente). Por eso se
# consulta desde el primer día del rango hasta el día siguiente al último, y cada parser
# recorta con la hora exacta del evento (eventtime, en epoch) al rango CDMX.
#
# La caché se identifica por perfil + equipo + RUN_ID. scripts_cron/run_*.sh exporta
# PCI_RUN_ID, así que todos los playbooks de una corrida comparten la misma sesión.
# Sin RUN_ID (playbook lanzado a mano) la caché se reutiliza si tiene menos de 30 min.
#
# La salida mezcla todas las consultas; cada parser filtra sus registros por campo
# (subtype, level, action, status, date).
#
# Uso: fortigate_collect_logs.sh <daily|weekly_events|weekly_traffic|quarterly_events> <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>

set -euo pipefail

if [[ $# -ne 8 ]]; then
    echo "Uso: $0 <daily|weekly_events|weekly_traffic|quarterly_events> <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>" >&2
    exit 1
fi

PROFILE="$1"
HOST="$2"
PORT="$3"
USER="$4"
PRIVATE_KEY="$5"
DEVICE="$6"
RUN_ID="$7"
CACHE_DIR="$8"

MANUAL_MAX_AGE_MIN=30
EVENT_SUBTYPES=(system vpn user)
# Severidades de System/VPN/User Events. Si se cambian, ajustar también --levels
# en system_events*/scripts/*.sh.
EVENT_SEVERITIES=(emergency alert critical error)
VIEW_LINES=1000
# Páginas por día para tráfico/webfilter (start=0,1000,...): el volumen diario
# supera el límite de view-lines (máx. 1000).
PAGE_STARTS=(0 1000 2000)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_WRAPPER="${SCRIPT_DIR}/fortigate_ssh.sh"

[[ -f "$SSH_WRAPPER" ]] || {
    echo "ERROR: No se encuentra el wrapper SSH: $SSH_WRAPPER" >&2
    exit 1
}

event_query() {
    local subtype="$1" severity="$2" query_date="$3"
    echo "execute log filter reset"
    echo "execute log filter category 1"
    echo "execute log filter field subtype ${subtype}"
    echo "execute log filter field level ${severity}"
    echo "execute log filter field date ${query_date}"
    echo "execute log filter view-lines ${VIEW_LINES}"
    echo "execute log display"
}

# query_dates <DÍAS|semana>: fechas (YYYY-MM-DD) a consultar en el FortiGate para el rango
# CDMX de <DÍAS> días: del primer día del rango al día siguiente del último (hoy).
query_dates() {
    local range start_date end_date current
    range="$(bash "${SCRIPT_DIR}/../../common/scripts/report_range.sh" "$1")"
    start_date="$(sed -n 's/.*"start_date":"\([0-9-]*\)".*/\1/p' <<<"$range")"
    end_date="$(sed -n 's/.*"end_date":"\([0-9-]*\)".*/\1/p' <<<"$range")"
    [[ -n "$start_date" && -n "$end_date" ]] || {
        echo "ERROR: No se pudo calcular el rango del reporte." >&2
        return 1
    }
    end_date="$(date -d "${end_date} +1 day" +%Y-%m-%d)"
    current="$start_date"
    while [[ ! "$current" > "$end_date" ]]; do
        echo "$current"
        current="$(date -d "${current} +1 day" +%Y-%m-%d)"
    done
}

daily_commands() {
    local query_date subtype severity
    local -a dates
    mapfile -t dates < <(query_dates 1)
    (( ${#dates[@]} > 0 )) || return 1

    for query_date in "${dates[@]}"; do
        # System/VPN/User Events
        for subtype in "${EVENT_SUBTYPES[@]}"; do
            for severity in "${EVENT_SEVERITIES[@]}"; do
                event_query "$subtype" "$severity" "$query_date"
            done
        done

        # Admin Login Failed
        echo "execute log filter reset"
        echo "execute log filter category 1"
        echo "execute log filter field subtype system"
        echo "execute log filter field level alert"
        echo "execute log filter field action login"
        echo "execute log filter field status failed"
        echo "execute log filter field date ${query_date}"
        echo "execute log filter view-lines ${VIEW_LINES}"
        echo "execute log display"

        # Alertamiento-Detección (cambios de configuración: subtype system, notice/information)
        for severity in notice information; do
            event_query system "$severity" "$query_date"
        done
    done
}

weekly_events_commands() {
    local report_date subtype severity
    local -a dates
    mapfile -t dates < <(query_dates semana)
    (( ${#dates[@]} > 0 )) || return 1

    for report_date in "${dates[@]}"; do
        # System/VPN/User Events
        for subtype in "${EVENT_SUBTYPES[@]}"; do
            for severity in "${EVENT_SEVERITIES[@]}"; do
                event_query "$subtype" "$severity" "$report_date"
            done
        done
    done
}

quarterly_events_commands() {
    local report_date severity
    local -a dates
    mapfile -t dates < <(query_dates 7)
    (( ${#dates[@]} > 0 )) || return 1

    for report_date in "${dates[@]}"; do
        # Eventos generales de seguridad: solo subtype system
        for severity in "${EVENT_SEVERITIES[@]}"; do
            event_query system "$severity" "$report_date"
        done
    done
}

weekly_traffic_commands() {
    local report_date page_start
    local -a dates
    mapfile -t dates < <(query_dates semana)
    (( ${#dates[@]} > 0 )) || return 1

    for report_date in "${dates[@]}"; do
        # Forward Traffic
        for page_start in "${PAGE_STARTS[@]}"; do
            echo "execute log filter reset"
            echo "execute log filter category 0"
            echo "execute log filter field type traffic"
            echo "execute log filter field subtype forward"
            echo "execute log filter field date ${report_date}"
            echo "execute log filter view-lines ${VIEW_LINES}"
            echo "execute log filter start ${page_start}"
            echo "execute log display"
        done

        # Webfilter
        for page_start in "${PAGE_STARTS[@]}"; do
            echo "execute log filter reset"
            echo "execute log filter category 3"
            echo "execute log filter field subtype webfilter"
            echo "execute log filter field date ${report_date}"
            echo "execute log filter view-lines ${VIEW_LINES}"
            echo "execute log filter start ${page_start}"
            echo "execute log display"
        done
    done
}

case "$PROFILE" in
    daily|weekly_events|weekly_traffic|quarterly_events) ;;
    *)
        echo "ERROR: Perfil desconocido: $PROFILE (usar daily, weekly_events, weekly_traffic o quarterly_events)" >&2
        exit 1
        ;;
esac

mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR"
umask 077

# Borra cachés de corridas anteriores (más de 1 día).
find "$CACHE_DIR" -maxdepth 1 -type f -name '*.log' -mmin +1440 -delete 2>/dev/null || true

SAFE_DEVICE="${DEVICE//[^A-Za-z0-9_.-]/_}"
if [[ -n "$RUN_ID" ]]; then
    CACHE_FILE="${CACHE_DIR}/${PROFILE}_${SAFE_DEVICE}_${RUN_ID//[^A-Za-z0-9_.-]/_}.log"
else
    CACHE_FILE="${CACHE_DIR}/${PROFILE}_${SAFE_DEVICE}_manual.log"
fi

# Evita que dos procesos abran sesión al mismo tiempo para el mismo equipo y perfil.
exec 9>"${CACHE_DIR}/${PROFILE}_${SAFE_DEVICE}.lock"
flock -w 3600 9 || {
    echo "ERROR: No se obtuvo el lock para ${DEVICE} (perfil ${PROFILE})" >&2
    exit 1
}

cache_is_valid() {
    [[ -s "$CACHE_FILE" ]] || return 1
    if [[ -n "$RUN_ID" ]]; then
        return 0
    fi
    [[ -n "$(find "$CACHE_FILE" -mmin -"$MANUAL_MAX_AGE_MIN" 2>/dev/null)" ]]
}

if cache_is_valid; then
    echo "Reutilizando logs ya descargados de ${DEVICE} (perfil ${PROFILE})" >&2
else
    # Los comandos se generan antes de conectarse: si falla el cálculo de fechas no se
    # abre la sesión.
    COMMANDS="$("${PROFILE}_commands")"
    echo "Iniciando sesión SSH en ${DEVICE} (perfil ${PROFILE}; los demás reportes del perfil la reutilizan)" >&2
    TMP_FILE="$(mktemp "${CACHE_DIR}/.${PROFILE}_${SAFE_DEVICE}.XXXXXX")"
    trap 'rm -f "$TMP_FILE"' EXIT
    printf '%s\n' "$COMMANDS" | bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" > "$TMP_FILE"
    mv -f "$TMP_FILE" "$CACHE_FILE"
    trap - EXIT
fi

cat "$CACHE_FILE"
