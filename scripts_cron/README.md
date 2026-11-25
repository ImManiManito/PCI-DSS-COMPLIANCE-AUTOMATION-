# scripts_cron

*[Read this document in English](README.en.md)*

Este directorio contiene los scripts programables para ejecutar los playbooks de
PCI-DSS-COMPLIANCE-AUTOMATION- según su frecuencia definida.

## Scripts disponibles

| Script              | Playbooks ejecutados       | Condición de ejecución                         |
|---------------------|----------------------------|------------------------------------------------|
| `run_daily.sh`      | `playbooks/daily/*.yml`    | Cada vez que se invoca                         |
| `run_weekly.sh`     | `playbooks/weekly/*.yml`   | Solo los lunes (`date +%u == 1`)               |
| `run_monthly.sh`    | `playbooks/monthly/*.yml` (excepto `account_activity.yml`) | Solo el día 1 de cada mes (`date +%d == 01`)   |
| `run_quarterly.sh`  | `playbooks/quarterly/*.yml` (excepto `available_logs.yml`) | Solo el día 1 de enero, abril, julio u octubre |
| `run_account_activity.sh` | `playbooks/monthly/account_activity.yml` | Solo el día 15 de cada mes |
| `run_available_logs.sh` | `playbooks/quarterly/available_logs.yml` | Solo el día 28 de marzo, junio, septiembre o diciembre |

## Requisitos

- Ejecutar en el controlador de Ansible (entorno Linux/WSL/Git Bash).
- Tener `ansible-playbook` disponible en el `PATH`.
- Hacer los scripts ejecutables:

  ```bash
  chmod +x scripts_cron/*.sh
  ```

## Uso de Ansible Vault

La contraseña del vault se toma sola, sin pedirla, del archivo
`~/.ansible/.vault_pass` del usuario que ejecuta cron (`vault_password_file` en
`ansible.cfg`). No hace falta exportar variables ni ponerlas en el crontab.
Crearlo una sola vez, como ese usuario:

```bash
install -d -m 700 ~/.ansible
( umask 077; read -rsp "Vault password: " p; echo; printf '%s\n' "$p" > ~/.ansible/.vault_pass; unset p )
chmod 400 ~/.ansible/.vault_pass
```

Si el archivo no existe, los scripts terminan con un error claro antes de ejecutar
los playbooks. Para usar otra ruta, exportar `ANSIBLE_VAULT_PASSWORD_FILE`.

## Configuración de cron (ejemplo)

```cron
# Diario a las 06:00
0 6 * * * /ruta/al/proyecto/scripts_cron/run_daily.sh >> /ruta/al/proyecto/logs/cron_daily.log 2>&1

# Semanal (lunes) a las 06:30
30 6 * * * /ruta/al/proyecto/scripts_cron/run_weekly.sh >> /ruta/al/proyecto/logs/cron_weekly.log 2>&1

# Mensual (día 1) a las 07:00
0 7 1 * * /ruta/al/proyecto/scripts_cron/run_monthly.sh >> /ruta/al/proyecto/logs/cron_monthly.log 2>&1

# Trimestral (1 de enero, abril, julio, octubre) a las 07:30
30 7 1 1,4,7,10 * /ruta/al/proyecto/scripts_cron/run_quarterly.sh >> /ruta/al/proyecto/logs/cron_quarterly.log 2>&1

# Actividad de cuentas (día 15) a las 07:00
0 7 15 * * /ruta/al/proyecto/scripts_cron/run_account_activity.sh >> /ruta/al/proyecto/logs/cron_account_activity.log 2>&1

# Logs disponibles 3M (28 de marzo, junio, septiembre, diciembre) a las 09:00 UTC (03:00 CDMX)
# Con el servidor en UTC, programar a las 06:00 UTC o después para que el día 28 ya sea 28 en CDMX.
0 9 28 3,6,9,12 * /ruta/al/proyecto/scripts_cron/run_available_logs.sh >> /ruta/al/proyecto/logs/cron_available_logs.log 2>&1
```

> Nota: aunque `run_weekly.sh`, `run_monthly.sh` y `run_quarterly.sh` incluyen su
> propia lógica de filtrado por fecha, se recomienda programar también las
> restricciones en cron para evitar ejecuciones innecesarias.

## Logs

Los scripts no generan archivos de log automáticamente; la salida se muestra por
`stdout`/`stderr`. Si deseas conservarla en un archivo, redirige manualmente al
invocar el script o en la configuración de cron, por ejemplo:

```bash
./scripts_cron/run_daily.sh >> /ruta/a/logs/daily_$(date +%Y%m%d_%H%M%S).log 2>&1
```
