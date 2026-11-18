#!/usr/bin/env bash
# scripts_cron/run_available_logs.sh
# Ejecuta el playbook trimestral playbooks/quarterly/available_logs.yml (3M - Logs
# disponibles) SOLO el día 28 de marzo, junio, septiembre y diciembre.
# run_quarterly.sh (día 1 de enero/abril/julio/octubre) omite este playbook: tiene su
# propio calendario.
#
# Frecuencia sugerida: programar en cron el día 28 de esos meses; el script vuelve a
# validar la fecha. El servidor está en UTC: programar a las 06:00 UTC o después, para
# que el día 28 ya haya empezado también en CDMX (UTC-6). Ejemplo (09:00 UTC = 03:00 CDMX):
#   0 9 28 3,6,9,12 * /ruta/al/proyecto/scripts_cron/run_available_logs.sh >> /ruta/al/log/cron_available_logs.log 2>&1
#
# La contraseña de Ansible Vault se lee sola de ~/.ansible/.vault_pass (permisos 400),
# sin pedirla. Para usar otra ruta: export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/.vault_pass

set -euo pipefail

DOM=$(date +%d)
MONTH=$(date +%m)

if [[ "${DOM}" != "28" ]] || [[ ! "${MONTH}" =~ ^(03|06|09|12)$ ]]; then
    echo "Hoy no es 28 de marzo, junio, septiembre o diciembre (dom=${DOM}, mes=${MONTH}). No se ejecuta Logs disponibles 3M."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK="${PROJECT_ROOT}/playbooks/quarterly/available_logs.yml"

# cron arranca en $HOME: hay que entrar al proyecto para que Ansible lea
# ansible.cfg (inventario inventory/hosts.ini y roles_path).
cd "${PROJECT_ROOT}"

# Identificador de esta corrida: los roles de FortiGate lo usan para abrir UNA sola
# sesión SSH por equipo y reutilizar esos logs durante la corrida.
PCI_RUN_ID="$(date +%Y%m%d%H%M%S)-$$"
export PCI_RUN_ID

# Directorio temporal privado de la corrida: ahí quedan los logs crudos de FortiGate.
# Se borra completo al terminar (con éxito o con error): no se guarda información en el
# servidor. Las evidencias de cada rol ya se eliminan en cuanto postfix acepta el correo.
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

log "Inicio ejecución Logs disponibles 3M"

if [[ ! -s "${PLAYBOOK}" ]]; then
    log "ERROR: No existe o está vacío el playbook ${PLAYBOOK}"
    exit 1
fi

# "|| rc=$?" evita que set -e aborte el script antes de registrar el resultado.
rc=0
ansible-playbook "${PLAYBOOK}" || rc=$?
if [[ ${rc} -eq 0 ]]; then
    log "OK: available_logs.yml"
else
    log "ERROR: available_logs.yml (código de salida ${rc})"
fi

log "Fin ejecución Logs disponibles 3M"
exit ${rc}
