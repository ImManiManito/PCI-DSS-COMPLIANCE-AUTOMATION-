#!/usr/bin/env bash
# scripts_cron/run_weekly.sh
# Ejecuta todos los playbooks del directorio playbooks/weekly/ SOLO los lunes.
#
# Frecuencia sugerida: programar diariamente en cron; el script decide si ejecuta.
# Programación típica en cron (ejemplo a las 06:30):
#   30 6 * * * /ruta/al/proyecto/scripts_cron/run_weekly.sh >> /ruta/al/proyecto/logs/cron_weekly.log 2>&1
#
# La contraseña de Ansible Vault se lee sola de ~/.ansible/.vault_pass (permisos 400),
# sin pedirla. Para usar otra ruta: export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/.vault_pass

set -euo pipefail

DOW=$(date +%u)  # 1=lunes, 7=domingo
if [[ "${DOW}" -ne 1 ]]; then
    echo "Hoy no es lunes (dow=${DOW}). No se ejecutan playbooks semanales."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK_DIR="${PROJECT_ROOT}/playbooks/weekly"

# cron arranca en $HOME: hay que entrar al proyecto para que Ansible lea
# ansible.cfg (inventario inventory/hosts.ini y roles_path).
cd "${PROJECT_ROOT}"

# Identificador de esta corrida: los roles de FortiGate lo usan para abrir UNA sola
# sesión SSH por equipo y reutilizar esos logs en todos los playbooks de la corrida.
PCI_RUN_ID="$(date +%Y%m%d%H%M%S)-$$"
export PCI_RUN_ID

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${msg}"
}

# Contraseña del vault: se toma sola de un archivo, sin pedirla (cron no tiene teclado).
# Por defecto ~/.ansible/.vault_pass, la misma ruta que vault_password_file en ansible.cfg.
VAULT_PASS_FILE="${ANSIBLE_VAULT_PASSWORD_FILE:-${HOME}/.ansible/.vault_pass}"
if [[ ! -r "${VAULT_PASS_FILE}" ]]; then
    log "ERROR: No se puede leer el archivo con la contraseña del vault: ${VAULT_PASS_FILE}"
    log "Créalo como el usuario que ejecuta cron (ver scripts_cron/README.md) o define ANSIBLE_VAULT_PASSWORD_FILE."
    exit 1
fi
export ANSIBLE_VAULT_PASSWORD_FILE="${VAULT_PASS_FILE}"
log "Usando vault password file: ${VAULT_PASS_FILE}"

log "Inicio ejecución semanal"
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
    ansible-playbook "${playbook}" || rc=$?
    if [[ ${rc} -eq 0 ]]; then
        log "OK: ${playbook_name}"
    else
        log "ERROR: ${playbook_name} (código de salida ${rc})"
        overall_exit=1
    fi
done

log "Fin ejecución semanal"
exit ${overall_exit}
