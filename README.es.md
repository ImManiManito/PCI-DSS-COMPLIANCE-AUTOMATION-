*[Read this document in English](README.md)*

# PCI DSS Compliance Automation

Este repositorio contiene un marco de automatización basado en Ansible para revisar controles de seguridad del PCI DSS de forma recurrente, recopilar evidencia y generar reportes operativos. El proyecto está diseñado con un enfoque modular: cada control se organiza en un playbook, uno o varios roles específicos por plataforma y scripts/plantillas auxiliares para recolectar y normalizar la información proveniente de FortiGate, Check Point y Wazuh.

## Estado actual del proyecto

El proyecto se encuentra en una etapa activa pero incremental de implementación. El repositorio incluye el flujo principal de automatización y la capa de ejecución programada. El estado actual es el siguiente:

- Controles diarios: implementados y operativos.
- Controles semanales: implementados y programados.
- Controles mensuales: Actividad de cuentas implementado; los demás definidos y pendientes de cierre o validación.
- Controles trimestrales: definidos, con funcionalidad activa en algunos casos y otros aún pendientes.

## Estructura del repositorio

```text
.
├── ansible.cfg                # Configuración global de Ansible
├── inventory/
│   └── hosts.ini             # Grupos del inventario para FortiGate, Check Point y Wazuh
├── playbooks/
│   ├── daily/
│   ├── weekly/
│   ├── monthly/
│   └── quarterly/
├── roles/
│   ├── common/               # Rango de fechas de los reportes y hora en CDMX
│   ├── fortigate/
│   ├── checkpoint/
│   └── wazuh/
├── scripts_cron/
│   └── *.sh                  # Puntos de entrada para ejecución programada
├── docs/
│   ├── architecture.md
│   └── architecture.es.md
├── README.md
├── README.es.md
└── vars/
```

## Cobertura de controles y estado

| Alcance PCI DSS | Actividad | Frecuencia | Estado |
|---|---|---|---|
| 10.2.4, 10.2.7, 10.4.1.a, 10.4.1.b, 10.6.1 | CHD SAD (`playbooks/daily/chd_sad.yml`) | Diaria | Implementado |
| 8.6.3.a, 8.6.3.b, 8.6.3.c | Contraseñas comprometidas (`playbooks/daily/compromised_passwords.yml`) | Diaria | Implementado |
| 10.7.1.a, 10.7.1.b, 10.7.2.a, 10.7.2.b, 10.7.3.a, 10.7.3.b | Fallas de infraestructura (`playbooks/daily/infrastructure_failures.yml`) | Diaria | Implementado |
| 10.2.4, 10.2.7, 10.6.1, 11.5.2.a, 11.5.2.b | Detección de cambios (`playbooks/weekly/change_detection.yml`) | Semanal | Implementado |
| 10.4.2.a, 10.4.2.b | Registros requeridos (`playbooks/weekly/required_logs.yml`) | Semanal | Implementado |
| 7.2.5.1.a, 7.2.5.1.b, 7.2.5.1.c | Registros de acceso (`playbooks/monthly/access_logs.yml`) | Mensual | Definido / pendiente |
| 8.2.6 | Actividad de cuentas (`playbooks/monthly/account_activity.yml`) | Día 15 de cada mes (registro semanal: `playbooks/weekly/account_activity_update.yml`) | Implementado |
| 10.4.2.1.a, 10.4.2.1.b | Evaluaciones periódicas (`playbooks/monthly/periodic_evaluations.yml`) | Mensual | Definido / pendiente |
| 7.2.4.a, 7.2.4.b | Cuentas privilegiadas (`playbooks/monthly/privileged_accounts.yml`) | Mensual | Definido / pendiente |
| 10.5.1.a, 10.5.1.b, 10.5.1.c | Registros disponibles (`playbooks/quarterly/available_logs.yml`) | Trimestral (día 28 de mar/jun/sep/dic) | Implementado |
| 8.3.9, 8.3.10.1 | Cambios de contraseña (`playbooks/quarterly/password_changes.yml`) | Trimestral | Implementado |
| 12.3.3 | Revisión de suites y protocolos (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Trimestral | Definido / pendiente |
| 11.2.1.a, 11.2.1.b, 11.2.1.c, 11.2.1.d | Puntos de acceso inalámbrico (`playbooks/quarterly/wireless_access_points.yml`) | Trimestral | Definido / pendiente |

## Componentes por plataforma

La automatización está organizada por tecnología:

- `roles/fortigate/`: recopilación y parseo de eventos y registros de equipos FortiGate, incluyendo cambios de configuración, eventos del sistema, revisión de tráfico y filtros web, además de flujos de cambio de contraseña.
- `roles/checkpoint/`: recopilación y parseo de eventos de Check Point como fallas de autenticación, aceptación de bloqueos y actividades relacionadas con IPS.
- `roles/wazuh/`: revisión local de Wazuh para correlación de alertas y análisis CHD/SAD, así como evidencia semanal.

Cada rol generalmente incluye carpetas `scripts/`, `tasks/` y `templates/`, además de lógica auxiliar para envío de correos y ejecución remota por SSH cuando es necesario.

## Rangos de fechas de los reportes

Todos los reportes usan días completos en hora de CDMX, calculados en un solo lugar (`roles/common/scripts/report_range.sh`):

- **Diarios**: el día anterior, de 00:00:00 a 23:59:59 CDMX.
- **Semanales**: la última semana completa, de lunes 00:00:00 a domingo 23:59:59 CDMX (p. ej. lunes 16 a domingo 22 de noviembre). Mientras es domingo, ese domingo no ha terminado, así que el semanal debe correr después de la medianoche del domingo (lunes temprano) para incluirlo.

Los rangos solo incluyen días ya terminados y las corridas consecutivas quedan contiguas, sin huecos ni traslapes. El servidor está en UTC y cada activo registra la hora a su manera, así que cada uno recorta por la hora exacta del evento:

- **FortiGate**: se consultan las fechas locales del equipo que toca el rango y el parser recorta con `eventtime` (epoch), sin depender de la zona horaria del equipo.
- **Check Point**: el rango se envía a la API en UTC.
- **Wazuh**: se leen el `alerts.json` del día y los archivos archivados (`AAAA/Mes/ossec-alerts-DD.json.gz`) y se recorta por el `timestamp` de cada alerta, respetando su offset.

La evidencia muestra la hora de cada evento en CDMX, del más reciente al más antiguo.

## Actividad de cuentas

El FortiGate conserva 7 días de logs, así que el último acceso de cada usuario VPN se guarda en un registro que se sobrescribe cada semana (`playbooks/weekly/account_activity_update.yml`, sin correo) y el día 15, al enviar la evidencia `ultimas conexiones VPN.txt` (`playbooks/monthly/account_activity.yml`: eapuser, logdesc, time). Se muestra lo más reciente entre la última conexión (tunnel-up) y el último cambio de contraseña (`passwd-time` del FortiGate o `password_changes.yml`).

Los accesos al portal (`Admin login successful`) se acumulan con el log completo en las mismas corridas y se envían en otro correo (`ultimas conexiones portal.txt`). Cuando postfix acepta el correo se eliminan del servidor, salvo el último inicio de sesión de cada usuario.

De Wazuh se envía, el día 15, la salida completa de `lastlog` (`Ultimas conexiones.txt`); no se guarda nada en el servidor.

De Check Point se envía, el día 15, la última conexión de cada usuario VPN (blade Mobile Access) de los últimos 90 días (`ultimas conexiones checkpoint.txt`); tampoco se guarda nada en el servidor.

- Lo de FortiGate es la única información que permanece en el servidor, en `~/.ansible/pci_state/` (0700, archivos 0600) del usuario que ejecuta Ansible: `fortigate_vpn_last_access.json` (usuario, logdesc y fechas) y `fortigate_admin_logins_<equipo>.txt` (logs completos pendientes de envío). Otra ruta con la variable de entorno `FORTIGATE_VPN_REGISTRY` (ruta del .json; el .txt se guarda en el mismo directorio).
- Carga inicial con la fecha del último cambio de contraseñas: `ansible-playbook playbooks/weekly/account_activity_update.yml -e fortigate_account_activity_password_date=AAAA-MM-DD`

## Arquitectura de despliegue

El proyecto asume actualmente que Ansible se ejecuta en el mismo host que el SIEM, en específico Wazuh. Esta es una limitación de infraestructura y no el estado ideal. Para conocer la justificación técnica y las implicaciones de seguridad de este diseño, consulta [docs/architecture.es.md](docs/architecture.es.md).

El archivo de inventario (`inventory/hosts.ini`) define los siguientes grupos:

- `fortigates`: conexión remota por SSH.
- `checkpoint`: ejecución local.
- `wazuh`: ejecución local.

## Manejo de secretos y ejecución automatizada

El proyecto utiliza Ansible Vault para proteger credenciales, endpoints de API y configuraciones operativas. Los valores sensibles no se mantienen en texto plano dentro del árbol del código fuente. La configuración por defecto espera que la contraseña del vault esté en `~/.ansible/.vault_pass` y la lee automáticamente desde `ansible.cfg`.

La ejecución programada se soporta mediante los scripts dentro de `scripts_cron/`:

- `run_daily.sh`
- `run_weekly.sh`
- `run_monthly.sh`
- `run_quarterly.sh`
- `run_account_activity.sh` (Actividad de cuentas: día 15 de cada mes)
- `run_available_logs.sh` (Registros disponibles 3M: día 28 de marzo, junio, septiembre y diciembre)

Estos scripts están diseñados para ejecutar los playbooks correspondientes según la frecuencia configurada y se integran con horarios cron.

Consulta [scripts_cron/README.md](scripts_cron/README.md) para ver ejemplos y detalles operativos.

## Ejemplo de uso

```bash
ansible-playbook playbooks/daily/chd_sad.yml
ansible-playbook playbooks/weekly/change_detection.yml
./scripts_cron/run_daily.sh
./scripts_cron/run_weekly.sh
```

## Nota de alcance

Este repositorio se enfoca en controles específicos de revisión de seguridad PCI DSS y en flujos de recolección de evidencia. No es una plataforma completa de cumplimiento empresarial, sino una base de automatización estructurada y repetible para los controles que ya están implementados o en desarrollo.
