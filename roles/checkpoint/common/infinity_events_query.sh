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
# (FILTRO_LUCENE puede ser "" para traer todos los logs del rango)

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
WINDOW_SECONDS=86400 # tamaño de cada ventana de búsqueda
POLL_INTERVAL=3      # segundos entre consultas de estado
POLL_MAX=100         # intentos de consulta de estado (~5 minutos por ventana)

# Logs por página. Con páginas de 1000 la API respondía 503 (vacío) en retrieve con logs
# pesados como IPS: no alcanza a armar la página. Se empieza con 200 y, si una página
# sigue fallando tras los reintentos, se repite la búsqueda de esa ventana con 50. Las
# páginas que ya se habían enviado se repiten, pero el parser descarta los duplicados.
PAGE_LIMITS=(200 50)
PAGE_INDEX=0         # tamaño en uso; una vez que baja, se mantiene para las demás ventanas

# Esperas entre reintentos cuando la API responde 429, 5xx (p. ej. 503 al descargar
# páginas con el servicio saturado) o falla la red: ~3 minutos en total por llamada.
RETRY_DELAYS=(5 10 20 40 60 60)

CURL_OPTS=(-sS --connect-timeout 15 --max-time 120)

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# 1) Autenticación en Infinity Portal: intercambia clientId/accessKey por un token temporal.
TOKEN=""
authenticate() {
    local response
    response="$(jq -n '{clientId: env.CHECKPOINT_CLIENT_ID, accessKey: env.CHECKPOINT_ACCESS_KEY}' \
        | curl "${CURL_OPTS[@]}" --fail --retry 3 --retry-delay 5 \
            -X POST "$AUTH_URL" -H "Content-Type: application/json" --data-binary @-)" \
        || die "Falló la autenticación en Infinity Portal ($AUTH_URL)."
    TOKEN="$(jq -r '.data.token // empty' <<<"$response")"
    [[ -n "$TOKEN" ]] || die "Infinity Portal no devolvió un token de autenticación."
}

# api <METHOD> <URL> [BODY]: llamada autenticada que imprime el cuerpo de la respuesta.
# El cuerpo de la petición viaja por stdin y el token en un descriptor de archivo, nunca
# en los argumentos de curl. Reintenta con espera creciente ante errores temporales y
# renueva el token una vez si expiró (401). Las respuestas se guardan solo en memoria.
api() {
    local method="$1" url="$2" body="${3:-}"
    local attempt=0 reauth=0 output code
    while true; do
        if [[ -n "$body" ]]; then
            output="$(curl "${CURL_OPTS[@]}" -w '\n%{http_code}' -X "$method" "$url" \
                -H "Content-Type: application/json" \
                -H @<(printf 'Authorization: Bearer %s\n' "$TOKEN") \
                --data-binary @- <<<"$body")" || output=$'\n000'
        else
            output="$(curl "${CURL_OPTS[@]}" -w '\n%{http_code}' -X "$method" "$url" \
                -H @<(printf 'Authorization: Bearer %s\n' "$TOKEN"))" || output=$'\n000'
        fi
        code="${output##*$'\n'}"
        output="${output%$'\n'*}"

        if [[ "$code" == 2?? ]]; then
            printf '%s\n' "$output"
            return 0
        fi
        if [[ "$code" == 401 ]] && (( reauth == 0 )); then
            echo "AVISO: token vencido (HTTP 401); se renueva la autenticación." >&2
            reauth=1
            authenticate
            continue
        fi
        if [[ "$code" == 429 || "$code" == 5?? || "$code" == 000 ]] && (( attempt < ${#RETRY_DELAYS[@]} )); then
            echo "AVISO: HTTP ${code} en ${method} ${url##*/}; reintento $(( attempt + 1 ))/${#RETRY_DELAYS[@]} en ${RETRY_DELAYS[attempt]} s." >&2
            sleep "${RETRY_DELAYS[attempt]}"
            attempt=$(( attempt + 1 ))
            continue
        fi
        echo "ERROR: HTTP ${code} en ${method} ${url##*/}: $(head -c 300 <<<"$output" | tr '\n' ' ')" >&2
        return 1
    done
}

authenticate

# 2) Búsqueda de una ventana de tiempo: crea la tarea, espera a que esté lista y
#    descarga todas sus páginas. Devuelve 2 si no se pudo descargar una página (para
#    repetir con páginas más chicas); cualquier otro error termina el script.
search_window() {
    local start="$1" end="$2" page_limit="$3"
    local body response task_id state="" page_token="" next_token attempt count pages=0 total=0
    local max_pages=$(( LIMIT / page_limit + 10 ))

    # Filtro vacío = todos los logs del rango (se omite el campo filter).
    body="$(jq -n --arg f "$FILTER" --arg s "$start" --arg e "$end" \
        --argjson limit "$LIMIT" --argjson page "$page_limit" \
        '{limit: $limit, pageLimit: $page, timeframe: {startTime: $s, endTime: $e}}
         + (if $f != "" then {filter: $f} else {} end)')"

    response="$(api POST "$EVENTS_URL" "$body")" \
        || die "No se pudo crear la búsqueda en Infinity Events ($start a $end)."
    task_id="$(jq -r '.data.taskId // empty' <<<"$response")"
    [[ -n "$task_id" ]] || die "Infinity Events no devolvió taskId ($start a $end)."

    # Se descarga en cuanto la búsqueda está "ready" (o "done"). No se espera solo a "done":
    # la API puede no marcar "done" hasta que se descargan las páginas y la espera se
    # quedaba congelada. Un 503 al descargar se resuelve con los reintentos de api().
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
        (( pages <= max_pages )) || die "Demasiadas páginas en una sola búsqueda ($start a $end)."

        body="$(jq -n --arg t "$task_id" --arg p "$page_token" '{taskId: $t, pageToken: $p}')"
        if ! response="$(api POST "${EVENTS_URL}/retrieve" "$body")"; then
            echo "AVISO: no se pudo descargar la página ${pages} con páginas de ${page_limit} logs ($start a $end)." >&2
            return 2
        fi
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

# query_window: busca una ventana; si una página falla, repite con páginas más chicas.
query_window() {
    local start="$1" end="$2" rc
    while (( PAGE_INDEX < ${#PAGE_LIMITS[@]} )); do
        rc=0
        search_window "$start" "$end" "${PAGE_LIMITS[PAGE_INDEX]}" || rc=$?
        (( rc == 0 )) && return 0
        PAGE_INDEX=$(( PAGE_INDEX + 1 ))
        if (( PAGE_INDEX < ${#PAGE_LIMITS[@]} )); then
            echo "AVISO: se repite la búsqueda $start a $end con páginas de ${PAGE_LIMITS[PAGE_INDEX]} logs." >&2
        fi
    done
    die "No se pudo descargar una página de resultados ($start a $end), ni con páginas de ${PAGE_LIMITS[-1]} logs."
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
