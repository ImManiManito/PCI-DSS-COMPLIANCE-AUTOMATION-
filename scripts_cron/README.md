# scripts_cron

*[Read this document in English](README.en.md)*

Este directorio contiene los scripts programables para ejecutar los playbooks de
PCI-DSS-COMPLIANCE-AUTOMATION- según su frecuencia definida.

## Scripts disponibles

| Script              | Playbooks ejecutados       | Condición de ejecución                         |
|---------------------|----------------------------|------------------------------------------------|
| `run_daily.sh`      | `playbooks/daily/*.yml`    | Cada vez que se invoca                         |
| `run_weekly.sh`     | `playbooks/weekly/*.yml`   | Solo los lunes (`date +%u == 1`)               |
| `run_monthly.sh`    | `playbooks/monthly/*.yml`  | Solo el día 1 de cada mes (`date +%d == 01`)   |
| `run_quarterly.sh`  | `playbooks/quarterly/*.yml`| Solo el día 1 de enero, abril, julio u octubre |

## Requisitos

- Ejecutar en el controlador de Ansible (entorno Linux/WSL/Git Bash).
- Tener `ansible-playbook` disponible en el `PATH`.
- Hacer los scripts ejecutables:

  ```bash
  chmod +x scripts_cron/*.sh
  ```

## Uso de Ansible Vault

Si se cifran las variables sensibles con Ansible Vault, crear un archivo con la
contraseña de Vault (por ejemplo, `~/.vault_pass`) con permisos restrictivos:

```bash
chmod 600 ~/.vault_pass
```

Y exportar la variable de entorno antes de la ejecución o en el crontab:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=/ruta/segura/.vault_pass
```

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
