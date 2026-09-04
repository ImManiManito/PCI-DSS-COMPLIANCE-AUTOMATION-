#!/usr/bin/env bash
# scripts_cron/run_quarterly.sh
# Ejecuta todos los playbooks del directorio playbooks/quarterly/
# SOLO el día 1 de enero, abril, julio y octubre.
#
# Frecuencia sugerida: programar diariamente en cron; el script decide si ejecuta.
# Programación típica en cron (ejemplo a las 07:30):
#   30 7 * * * /ruta/al/proyecto/scripts_cron/run_quarterly.sh >> /ruta/al/proyecto/logs/cron_quarterly.log 2>&1
#
# Si se usa Ansible Vault, exportar la variable de entorno antes de ejecutar:
#   export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/segura/.vault_pass

set -euo pipefail

DOM=$(date +%d)
MONTH=$(date +%m)
quarterly_months="01 04 07 10"

if [[ "${DOM}" != "01" ]] || [[ ! "${quarterly_months}" =~ ${MONTH} ]]; then
    echo "Hoy no es el primer día de un trimestre (dom=${DOM}, mes=${MONTH}). No se ejecutan playbooks trimestrales."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK_DIR="${PROJECT_ROOT}/playbooks/quarterly"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${msg}"
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

log "Inicio ejecución trimestral"
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
    ansible-playbook "${ANSIBLE_ARGS[@]}" "${playbook}"
    rc=$?
    if [[ ${rc} -eq 0 ]]; then
        log "OK: ${playbook_name}"
    else
        log "ERROR: ${playbook_name} (código de salida ${rc})"
        overall_exit=1
    fi
done

log "Fin ejecución trimestral"
exit ${overall_exit}
