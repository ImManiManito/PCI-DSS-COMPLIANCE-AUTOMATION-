#!/usr/bin/env bash
# Descarga en UNA sola sesión SSH por FortiGate todos los logs que necesita una
# ejecución y los guarda en caché. Los demás roles de la misma ejecución reutilizan
# esa caché en lugar de volver a iniciar sesión en el equipo.
#
# Perfiles:
#   daily  -> System/VPN/User Events (24 h), Admin Login Failed y Alertamiento-Detección
#   weekly -> System/VPN/User Events, Forward Traffic y Webfilter (últimos 7 días)
#
# La caché se identifica por perfil + equipo + RUN_ID. scripts_cron/run_*.sh exporta
# PCI_RUN_ID, así que todos los playbooks de una corrida comparten la misma sesión.
# Sin RUN_ID (playbook lanzado a mano) la caché se reutiliza si tiene menos de 30 min.
#
# La salida mezcla todas las consultas; cada parser filtra sus registros por campo
# (subtype, level, action, status, date).
#
# Uso: fortigate_collect_logs.sh <daily|weekly> <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>

set -euo pipefail

if [[ $# -ne 8 ]]; then
    echo "Uso: $0 <daily|weekly> <HOST> <PORT> <USER> <PRIVATE_KEY> <DEVICE> <RUN_ID> <CACHE_DIR>" >&2
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

daily_commands() {
    local query_date subtype severity today

    # System/VPN/User Events, ventana móvil de 24 h: el FortiGate (UTC) filtra por
    # fecha, así que se consultan ayer y hoy (UTC) y el parser recorta por hora en CDMX.
    for query_date in "$(date -u -d '-1 day' +%Y-%m-%d)" "$(date -u +%Y-%m-%d)"; do
        for subtype in "${EVENT_SUBTYPES[@]}"; do
            for severity in "${EVENT_SEVERITIES[@]}"; do
                event_query "$subtype" "$severity" "$query_date"
            done
        done
    done

    today="$(date +%Y-%m-%d)"

    # Admin Login Failed
    echo "execute log filter reset"
    echo "execute log filter category 1"
    echo "execute log filter field subtype system"
    echo "execute log filter field level alert"
    echo "execute log filter field action login"
    echo "execute log filter field status failed"
    echo "execute log filter field date ${today}"
    echo "execute log filter view-lines ${VIEW_LINES}"
    echo "execute log display"

    # Alertamiento-Detección (cambios de configuración: subtype system, notice/information)
    for severity in notice information; do
        event_query system "$severity" "$today"
    done
}

weekly_commands() {
    local day_offset report_date subtype severity page_start

    # 0 = hoy, 6 = hace 6 días -> ventana de 7 días
    for day_offset in 0 1 2 3 4 5 6; do
        report_date="$(date -d "-${day_offset} day" +%Y-%m-%d)"

        # System/VPN/User Events
        for subtype in "${EVENT_SUBTYPES[@]}"; do
            for severity in "${EVENT_SEVERITIES[@]}"; do
                event_query "$subtype" "$severity" "$report_date"
            done
        done

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
    daily|weekly) ;;
    *)
        echo "ERROR: Perfil desconocido: $PROFILE (usar daily o weekly)" >&2
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
    echo "Iniciando sesión SSH única en ${DEVICE} (perfil ${PROFILE})" >&2
    TMP_FILE="$(mktemp "${CACHE_DIR}/.${PROFILE}_${SAFE_DEVICE}.XXXXXX")"
    trap 'rm -f "$TMP_FILE"' EXIT
    "${PROFILE}_commands" | bash "$SSH_WRAPPER" "$HOST" "$PORT" "$USER" "$PRIVATE_KEY" > "$TMP_FILE"
    mv -f "$TMP_FILE" "$CACHE_FILE"
    trap - EXIT
fi

cat "$CACHE_FILE"
