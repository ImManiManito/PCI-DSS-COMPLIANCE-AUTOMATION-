#!/usr/bin/env bash
# Consulta logs en Check Point Infinity Events (API de Infinity Portal) y vuelca a
# stdout cada página de resultados como una línea JSON compacta.
#
# Flujo de la API (asíncrono, 3 pasos):
#   1) POST <EVENTS_URL>              -> crea la búsqueda y devuelve data.taskId
#   2) GET  <EVENTS_URL>/<taskId>     -> estado de la búsqueda (data.state, data.pageTokens)
#   3) POST <EVENTS_URL>/retrieve     -> página de resultados (data.records, data.nextPageToken)
#
# EVENTS_URL es el endpoint logs_query del tenant, por ejemplo:
#   https://cloudinfra-gw-us.portal.checkpoint.com/app/laas-logs-api/api/logs_query
#
# La API devuelve como máximo 10000 logs por búsqueda, así que el rango se consulta
# en ventanas de 24 horas (una búsqueda por día). Las ventanas comparten el instante
# de corte; el parser descarta los registros repetidos.
#
# Credenciales: se leen de las variables de entorno CHECKPOINT_CLIENT_ID y
# CHECKPOINT_ACCESS_KEY. Ni ellas ni el token se pasan como argumentos de ningún
# proceso (no aparecen en la lista de procesos).
#
# Cualquier error (red, HTTP, autenticación, búsqueda cancelada) termina con código
# distinto de 0 para que no se envíe evidencia vacía como si no hubiera eventos.
#
# Uso: infinity_events_query.sh <AUTH_URL> <EVENTS_URL> <START_ISO8601> <END_ISO8601> <FILTRO_LUCENE>

set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Uso: $0 <AUTH_URL> <EVENTS_URL> <START_TIME_ISO8601> <END_TIME_ISO8601> <FILTRO>" >&2
    echo "Requiere las variables de entorno CHECKPOINT_CLIENT_ID y CHECKPOINT_ACCESS_KEY." >&2
    exit 1
fi

AUTH_URL="$1"
EVENTS_URL="${2%/}"
START_TIME="$3"
END_TIME="$4"
FILTER="$5"

: "${CHECKPOINT_CLIENT_ID:?ERROR: Falta la variable de entorno CHECKPOINT_CLIENT_ID}"
: "${CHECKPOINT_ACCESS_KEY:?ERROR: Falta la variable de entorno CHECKPOINT_ACCESS_KEY}"
export CHECKPOINT_CLIENT_ID CHECKPOINT_ACCESS_KEY

command -v curl >/dev/null 2>&1 || { echo "ERROR: se requiere 'curl'." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: se requiere 'jq'." >&2; exit 1; }

LIMIT=10000          # máximo de logs por búsqueda que permite la API
PAGE_LIMIT=1000      # máximo de logs por página que permite la API
WINDOW_SECONDS=86400 # tamaño de cada ventana de búsqueda
POLL_INTERVAL=3      # segundos entre consultas de estado
POLL_MAX=100         # intentos de consulta de estado (~5 minutos por ventana)
MAX_PAGES=50         # tope de páginas por ventana (LIMIT / PAGE_LIMIT = 10)

CURL_OPTS=(-sS --fail --connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5)

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# api <METHOD> <URL> [BODY]: llamada autenticada; el cuerpo viaja por stdin y el
# token en un descriptor de archivo, nunca en los argumentos de curl.
api() {
    local method="$1" url="$2" body="${3:-}"
    if [[ -n "$body" ]]; then
        curl "${CURL_OPTS[@]}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -H @<(printf 'Authorization: Bearer %s\n' "$TOKEN") \
            --data-binary @- <<<"$body"
    else
        curl "${CURL_OPTS[@]}" -X "$method" "$url" \
            -H @<(printf 'Authorization: Bearer %s\n' "$TOKEN")
    fi
}

# 1) Autenticación en Infinity Portal: intercambia clientId/accessKey por un token temporal.
AUTH_RESPONSE="$(jq -n '{clientId: env.CHECKPOINT_CLIENT_ID, accessKey: env.CHECKPOINT_ACCESS_KEY}' \
    | curl "${CURL_OPTS[@]}" -X POST "$AUTH_URL" -H "Content-Type: application/json" --data-binary @-)" \
    || die "Falló la autenticación en Infinity Portal ($AUTH_URL)."

TOKEN="$(jq -r '.data.token // empty' <<<"$AUTH_RESPONSE")"
[[ -n "$TOKEN" ]] || die "Infinity Portal no devolvió un token de autenticación."

# 2) Búsqueda de una ventana de tiempo: crea la tarea, espera a que esté lista y
#    descarga todas sus páginas.
query_window() {
    local start="$1" end="$2"
    local body response task_id state="" page_token="" next_token attempt count pages=0 total=0

    body="$(jq -n --arg f "$FILTER" --arg s "$start" --arg e "$end" \
        --argjson limit "$LIMIT" --argjson page "$PAGE_LIMIT" \
        '{filter: $f, limit: $limit, pageLimit: $page, timeframe: {startTime: $s, endTime: $e}}')"

    response="$(api POST "$EVENTS_URL" "$body")" \
        || die "No se pudo crear la búsqueda en Infinity Events ($start a $end)."
    task_id="$(jq -r '.data.taskId // empty' <<<"$response")"
    [[ -n "$task_id" ]] || die "Infinity Events no devolvió taskId ($start a $end)."

    for (( attempt = 0; attempt < POLL_MAX; attempt++ )); do
        response="$(api GET "${EVENTS_URL}/${task_id}")" \
            || die "No se pudo consultar el estado de la búsqueda ($start a $end)."
        state="$(jq -r '(.data.state // "") | ascii_downcase' <<<"$response")"
        case "$state" in
            ready|done)
                break
                ;;
            canceled|cancelled|failed|error)
                die "Infinity Events canceló la búsqueda ($start a $end): $(jq -c '.data.errors // []' <<<"$response")"
                ;;
        esac
        sleep "$POLL_INTERVAL"
    done
    [[ "$state" == "ready" || "$state" == "done" ]] \
        || die "La búsqueda no terminó a tiempo ($start a $end, último estado: ${state:-desconocido})."

    page_token="$(jq -r '.data.pageTokens[0] // empty' <<<"$response")"

    # Sin pageToken (o "NULL") no hay resultados para esta ventana.
    while [[ -n "$page_token" && "${page_token^^}" != "NULL" ]]; do
        pages=$(( pages + 1 ))
        (( pages <= MAX_PAGES )) || die "Demasiadas páginas en una sola búsqueda ($start a $end)."

        body="$(jq -n --arg t "$task_id" --arg p "$page_token" '{taskId: $t, pageToken: $p}')"
        response="$(api POST "${EVENTS_URL}/retrieve" "$body")" \
            || die "No se pudo descargar una página de resultados ($start a $end)."
        [[ "$(jq -r '.success // false' <<<"$response")" == "true" ]] \
            || die "Infinity Events devolvió un error al descargar resultados ($start a $end)."

        jq -c . <<<"$response"

        count="$(jq -r '(.data.records // []) | length' <<<"$response")"
        total=$(( total + count ))

        next_token="$(jq -r '.data.nextPageToken // empty' <<<"$response")"
        [[ "$next_token" != "$page_token" ]] || die "La API repitió el mismo pageToken ($start a $end)."
        page_token="$next_token"
    done

    if (( total >= LIMIT )); then
        echo "AVISO: $start a $end alcanzó el máximo de $LIMIT logs por búsqueda; puede haber más eventos sin incluir." >&2
    fi
}

# 3) Recorre el rango pedido en ventanas de 24 horas.
START_EPOCH="$(date -u -d "$START_TIME" +%s)" || die "Fecha de inicio no válida: $START_TIME"
END_EPOCH="$(date -u -d "$END_TIME" +%s)" || die "Fecha de fin no válida: $END_TIME"
(( START_EPOCH < END_EPOCH )) || die "El inicio del rango debe ser anterior al fin."

WINDOW_START="$START_EPOCH"
while (( WINDOW_START < END_EPOCH )); do
    WINDOW_END=$(( WINDOW_START + WINDOW_SECONDS ))
    (( WINDOW_END <= END_EPOCH )) || WINDOW_END="$END_EPOCH"

    query_window \
        "$(date -u -d "@${WINDOW_START}" +%Y-%m-%dT%H:%M:%SZ)" \
        "$(date -u -d "@${WINDOW_END}" +%Y-%m-%dT%H:%M:%SZ)"

    WINDOW_START="$WINDOW_END"
done
