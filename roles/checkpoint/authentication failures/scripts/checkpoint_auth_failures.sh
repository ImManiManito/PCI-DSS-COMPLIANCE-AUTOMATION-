#!/usr/bin/env bash
# Consulta eventos de autenticación (VPN, Action=Block) en Check Point Infinity
# Events (Infinity Portal API) y vuelca cada página de resultados JSON (una por
# línea) a stdout.
#
# Autenticación: las credenciales (clientId/accessKey) se leen de las variables
# de entorno CHECKPOINT_CLIENT_ID y CHECKPOINT_ACCESS_KEY (no se pasan como
# argumentos para no exponerlas en la lista de procesos).
#
# NOTA: el cuerpo del request/paginación de la consulta de eventos debe validarse
# contra el contrato real de la API de Infinity Events del tenant (puede variar
# el nombre de los campos de filtro/paginación respecto a lo aquí implementado).

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Uso: $0 <AUTH_URL> <EVENTS_URL> <START_TIME_ISO8601> <END_TIME_ISO8601>" >&2
    echo "Requiere las variables de entorno CHECKPOINT_CLIENT_ID y CHECKPOINT_ACCESS_KEY." >&2
    exit 1
fi

AUTH_URL="$1"
EVENTS_URL="$2"
START_TIME="$3"
END_TIME="$4"

: "${CHECKPOINT_CLIENT_ID:?ERROR: Falta la variable de entorno CHECKPOINT_CLIENT_ID}"
: "${CHECKPOINT_ACCESS_KEY:?ERROR: Falta la variable de entorno CHECKPOINT_ACCESS_KEY}"

command -v curl >/dev/null 2>&1 || { echo "ERROR: se requiere 'curl'." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere 'jq'." >&2; exit 1; }

# 1) Autenticación en Infinity Portal: intercambia clientId/accessKey por un token temporal.
AUTH_RESPONSE="$(curl -sS -X POST "$AUTH_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg id "$CHECKPOINT_CLIENT_ID" --arg key "$CHECKPOINT_ACCESS_KEY" \
        '{clientId: $id, accessKey: $key}')")"

TOKEN="$(echo "$AUTH_RESPONSE" | jq -r '.data.token // empty')"

[[ -n "$TOKEN" ]] || {
    echo "ERROR: No se pudo obtener el token de autenticación de Infinity Portal." >&2
    echo "Respuesta: $AUTH_RESPONSE" >&2
    exit 1
}

# 2) Consulta paginada de eventos de autenticación (blade VPN, action Block) de
#    las últimas 24h, trayendo todos los resultados.
PAGE_TOKEN=""

while true; do
    REQUEST_BODY="$(jq -n \
        --arg start "$START_TIME" \
        --arg end "$END_TIME" \
        --arg pageToken "$PAGE_TOKEN" \
        '{
            filter: {
                blades: ["VPN"],
                action: "Block",
                timeframe: { start: $start, end: $end }
            },
            pageSize: 200
        } + (if $pageToken != "" then {pageToken: $pageToken} else {} end)')"

    RESPONSE="$(curl -sS -X POST "$EVENTS_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d "$REQUEST_BODY")"

    echo "$RESPONSE"

    PAGE_TOKEN="$(echo "$RESPONSE" | jq -r '.nextPageToken // empty')"

    [[ -n "$PAGE_TOKEN" ]] || break
done
