#!/usr/bin/env bash
# scripts_cron/run_daily.sh
# Ejecuta todos los playbooks del directorio playbooks/daily/.
#
# Frecuencia sugerida: diaria.
# Programación típica en cron (ejemplo a las 06:00):
#   0 6 * * * /ruta/al/proyecto/scripts_cron/run_daily.sh >> /ruta/al/proyecto/logs/cron_daily.log 2>&1
#
# Si se usa Ansible Vault, exportar la variable de entorno antes de ejecutar:
#   export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/segura/.vault_pass

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK_DIR="${PROJECT_ROOT}/playbooks/daily"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/daily_${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${msg}"
    echo "${msg}" >> "${LOG_FILE}"
}

ANSIBLE_ARGS=()
if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
    if [[ -f "${ANSIBLE_VAULT_PASSWORD_FILE}" ]]; then
        ANSIBLE_ARGS+=(--vault-password-file "${ANSIBLE_VAULT_PASSWORD_FILE}")
        log "Usando vault password file: ${ANSIBLE_VAULT_PASSWORD_FILE}"
    else
        log "ADVERTENCIA: ANSIBLE_VAULT_PASSWORD_FILE=${ANSIBLE_VAULT_PASSWORD_FILE} no existe."
    fi
fi

log "Inicio ejecución diaria"
log "Directorio de playbooks: ${PLAYBOOK_DIR}"

shopt -s nullglob
playbooks=("${PLAYBOOK_DIR}"/*.yml)
shopt -u nullglob

if [[ ${#playbooks[@]} -eq 0 ]]; then
    log "No se encontraron playbooks en ${PLAYBOOK_DIR}"
    exit 0
fi

overall_exit=0
for playbook in "${playbooks[@]}"; do
    playbook_name=$(basename "${playbook}")
    log "Ejecutando playbook: ${playbook_name}"
    ansible-playbook "${ANSIBLE_ARGS[@]}" "${playbook}" >> "${LOG_FILE}" 2>&1
    rc=$?
    if [[ ${rc} -eq 0 ]]; then
        log "OK: ${playbook_name}"
    else
        log "ERROR: ${playbook_name} (código de salida ${rc})"
        overall_exit=1
    fi
done

log "Fin ejecución diaria"
exit ${overall_exit}
