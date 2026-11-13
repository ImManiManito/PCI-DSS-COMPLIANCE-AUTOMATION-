*[Read this document in English](README.md)*

# PCI DSS Compliance Automation

Este repositorio contiene un marco de automatización basado en Ansible para revisar controles de seguridad del PCI DSS de forma recurrente, recopilar evidencia y generar reportes operativos. El proyecto está diseñado con un enfoque modular: cada control se organiza en un playbook, uno o varios roles específicos por plataforma y scripts/plantillas auxiliares para recolectar y normalizar la información proveniente de FortiGate, Check Point y Wazuh.

## Estado actual del proyecto

El proyecto se encuentra en una etapa activa pero incremental de implementación. El repositorio incluye el flujo principal de automatización y la capa de ejecución programada. El estado actual es el siguiente:

- Controles diarios: implementados y operativos.
- Controles semanales: implementados y programados.
- Controles mensuales: definidos en el repositorio y pendientes de cierre o validación.
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
| 8.2.6 | Actividad de cuentas (`playbooks/monthly/account_activity.yml`) | Mensual | Definido / pendiente |
| 10.4.2.1.a, 10.4.2.1.b | Evaluaciones periódicas (`playbooks/monthly/periodic_evaluations.yml`) | Mensual | Definido / pendiente |
| 7.2.4.a, 7.2.4.b | Cuentas privilegiadas (`playbooks/monthly/privileged_accounts.yml`) | Mensual | Definido / pendiente |
| 10.5.1.a, 10.5.1.b, 10.5.1.c | Registros disponibles (`playbooks/quarterly/available_logs.yml`) | Trimestral | Definido / pendiente |
| 8.3.9, 8.3.10.1 | Cambios de contraseña (`playbooks/quarterly/password_changes.yml`) | Trimestral | Implementado |
| 12.3.3 | Revisión de suites y protocolos (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Trimestral | Definido / pendiente |
| 11.2.1.a, 11.2.1.b, 11.2.1.c, 11.2.1.d | Puntos de acceso inalámbrico (`playbooks/quarterly/wireless_access_points.yml`) | Trimestral | Definido / pendiente |

## Componentes por plataforma

La automatización está organizada por tecnología:

- `roles/fortigate/`: recopilación y parseo de eventos y registros de equipos FortiGate, incluyendo cambios de configuración, eventos del sistema, revisión de tráfico y filtros web, además de flujos de cambio de contraseña.
- `roles/checkpoint/`: recopilación y parseo de eventos de Check Point como fallas de autenticación, aceptación de bloqueos y actividades relacionadas con IPS.
- `roles/wazuh/`: revisión local de Wazuh para correlación de alertas y análisis CHD/SAD, así como evidencia semanal.

Cada rol generalmente incluye carpetas `scripts/`, `tasks/` y `templates/`, además de lógica auxiliar para envío de correos y ejecución remota por SSH cuando es necesario.

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
