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

# cron arranca en $HOME: hay que entrar al proyecto para que Ansible lea
# ansible.cfg (inventario inventory/hosts.ini y roles_path).
cd "${PROJECT_ROOT}"

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
    if [[ ! -s "${playbook}" ]]; then
        log "OMITIDO: ${playbook_name} (archivo vacío)"
        continue
    fi
    log "Ejecutando playbook: ${playbook_name}"
    # "|| rc=$?" evita que set -e aborte el script y deje sin correr los demás playbooks.
    rc=0
    ansible-playbook "${ANSIBLE_ARGS[@]}" "${playbook}" || rc=$?
    if [[ ${rc} -eq 0 ]]; then
        log "OK: ${playbook_name}"
    else
        log "ERROR: ${playbook_name} (código de salida ${rc})"
        overall_exit=1
    fi
done

log "Fin ejecución diaria"
exit ${overall_exit}
