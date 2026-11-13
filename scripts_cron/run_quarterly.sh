#!/usr/bin/env bash
# scripts_cron/run_quarterly.sh
# Ejecuta todos los playbooks del directorio playbooks/quarterly/
# SOLO el día 1 de enero, abril, julio y octubre.
#
# Frecuencia sugerida: programar diariamente en cron; el script decide si ejecuta.
# Programación típica en cron (ejemplo a las 07:30):
#   30 7 * * * /ruta/al/proyecto/scripts_cron/run_quarterly.sh >> /ruta/al/proyecto/logs/cron_quarterly.log 2>&1
#
# La contraseña de Ansible Vault se lee sola de ~/.ansible/.vault_pass (permisos 400),
# sin pedirla. Para usar otra ruta: export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/.vault_pass

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

# cron arranca en $HOME: hay que entrar al proyecto para que Ansible lea
# ansible.cfg (inventario inventory/hosts.ini y roles_path).
cd "${PROJECT_ROOT}"

# Identificador de esta corrida: los roles de FortiGate lo usan para abrir UNA sola
# sesión SSH por equipo y reutilizar esos logs en todos los playbooks de la corrida.
PCI_RUN_ID="$(date +%Y%m%d%H%M%S)-$$"
export PCI_RUN_ID

# Directorio temporal privado de la corrida: ahí quedan los logs crudos de FortiGate
# que comparten los playbooks. Se borra completo al terminar (con éxito o con error):
# no se guarda información en el servidor. Las evidencias de cada rol ya se eliminan
# en cuanto postfix acepta el correo.
PCI_RUN_TMPDIR="$(mktemp -d -t pci_run_XXXXXX)"
export PCI_RUN_TMPDIR
trap 'rm -rf "${PCI_RUN_TMPDIR}"' EXIT

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

log "Fin ejecución trimestral"
exit ${overall_exit}
