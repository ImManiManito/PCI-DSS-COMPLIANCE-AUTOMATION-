*[Read this document in English](README.md)*

# PCI-DSS-COMPLIANCE-AUTOMATION-

PCI-DSS-COMPLIANCE-AUTOMATION- es un proyecto de automatización diseñado para agilizar la ejecución y el monitoreo de actividades relacionadas con el PCI DSS (Payment Card Industry Data Security Standard).

El proyecto utiliza Ansible como su plataforma principal de automatización e integra varias tecnologías de seguridad, incluyendo FortiGate, Check Point y Wazuh, para recolectar información de seguridad, procesar eventos y generar evidencia estandarizada de cumplimiento.

Las actividades se organizan según su frecuencia de ejecución:

Diario -- Semanal -- Mensual -- Trimestral

La arquitectura del proyecto está diseñada para mantener cada actividad organizada e independiente, separando los playbooks de ejecución, las tareas de Ansible y los scripts utilizados para recolectar y procesar la información de seguridad.

playbooks/
    Actividades organizadas por frecuencia de ejecución.

roles/
    Automatización específica por plataforma.

files/
    Scripts, parsers y archivos auxiliares para cada actividad.

common/
    Componentes compartidos entre varias actividades.

inventory/
    Inventario de infraestructura.

scripts_cron/
    Ejecuciones programadas y automatizadas.

El proyecto también utiliza Ansible Vault para proteger credenciales, claves de API y otra información sensible, garantizando que los secretos no se almacenen directamente en el código fuente.

## Arquitectura de despliegue

Idealmente, Ansible debería ejecutarse en una máquina virtual o activo dedicado, separado del SIEM. Para este proyecto, debido a las limitaciones actuales de infraestructura, Ansible se ejecuta en el mismo activo que aloja el SIEM (Wazuh). Consulta [docs/architecture.es.md](docs/architecture.es.md) (también disponible [en inglés](docs/architecture.md)) para más detalles y las consideraciones de seguridad derivadas de esta decisión.

El inventario (`inventory/hosts.ini`) actualmente define tres grupos: `fortigates` (remoto, vía SSH), `checkpoint` (conexión local) y `wazuh` (conexión local).

El objetivo principal de esta iniciativa es reducir los procesos manuales, mejorar la consistencia y confiabilidad de las actividades de seguridad, y facilitar la generación de evidencia para las revisiones y auditorías de cumplimiento PCI DSS.

## Estado de implementación

No todas las actividades están implementadas todavía. La siguiente tabla refleja el estado actual del repositorio.

| Plataforma | Actividad | Estado |
|---|---|---|
| FortiGate | `system_events` | Implementado (script de recolección, parser, plantilla de reporte, tarea) |
| FortiGate | `system_events_7_days` | Implementado (script de recolección, parser, plantilla de reporte, tarea) |
| FortiGate | `security_events_and_forward_traffic` | Implementado (script de recolección, parser, plantillas de reporte, tarea) |
| FortiGate | `admin_login_failed` | Pendiente |
| FortiGate | `configuration_changes` | Pendiente |
| Check Point | `authentication failures`, `block-acceptance`, `checkpoint_audits`, `events_ips` | Pendiente (solo estructura de carpetas) |
| Wazuh | integración local del SIEM | Pendiente |

Actualmente el playbook **diario** `chd_sad.yml` (eventos de sistema de FortiGate, últimas 24 horas) y el playbook **semanal** `change_detection.yml` (eventos de sistema y de seguridad/tráfico saliente de FortiGate, últimos 7 días) ejecutan tareas implementadas; el resto de los playbooks diarios, semanales, mensuales y trimestrales son plantillas pendientes de completar a medida que se desarrolle cada actividad. `scripts_cron/` también está vacío por ahora, a la espera de las ejecuciones programadas de las actividades anteriores.

Los roles de FortiGate dependen de utilidades compartidas en `roles/fortigate/common/` (`fortigate_ssh.sh` para la ejecución remota por CLI y `send_mail_report.sh` para el envío de evidencia por correo) y de `roles/fortigate/vars/vault.yml` para la configuración de correo, el cual debe completarse y cifrarse con Ansible Vault antes de usarse en producción.
