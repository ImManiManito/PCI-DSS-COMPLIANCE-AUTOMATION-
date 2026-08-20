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

## Mapeo de cumplimiento con PCI DSS

La siguiente tabla mapea cada actividad (playbook) con los requisitos de PCI DSS que cumple y la periodicidad con la que se ejecuta.

| Actividad (playbook) | Periodicidad | Requisitos PCI DSS | Estado |
|---|---|---|---|
| CHD SAD (`playbooks/daily/chd_sad.yml`) | Diaria | 10.4.1.a, 10.4.1.b | Implementado |
| Contraseñas comprometidas (`playbooks/daily/compromised_passwords.yml`) | Diaria | 8.6.3.a, 8.6.3.b, 8.6.3.c | Implementado |
| Fallas de infraestructura (`playbooks/daily/infrastructure_failures.yml`) | Diaria | 10.7.1.a, 10.7.1.b, 10.7.2.a, 10.7.2.b, 10.7.3.a, 10.7.3.b | Implementado |
| Detección de cambios (`playbooks/weekly/change_detection.yml`) | Semanal | Pendiente de mapeo | Implementado |
| Registros requeridos (`playbooks/weekly/required_logs.yml`) | Semanal | 10.4.2.a, 10.4.2.b | Implementado |
| Registros de acceso (`playbooks/monthly/access_logs.yml`) | Mensual | Pendiente de mapeo | Pendiente |
| Actividad de cuentas (`playbooks/monthly/account_activity.yml`) | Mensual | Pendiente de mapeo | Pendiente |
| Evaluaciones periódicas (`playbooks/monthly/periodic_evaluations.yml`) | Mensual | Pendiente de mapeo | Pendiente |
| Cuentas privilegiadas (`playbooks/monthly/privileged_accounts.yml`) | Mensual | Pendiente de mapeo | Pendiente |
| Registros disponibles (`playbooks/quarterly/available_logs.yml`) | Trimestral | Pendiente de mapeo | Pendiente |
| Cambios de contraseña (`playbooks/quarterly/password_changes.yml`) | Trimestral | Pendiente de mapeo | Pendiente |
| Revisión de suites y protocolos (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Trimestral | Pendiente de mapeo | Pendiente |
| Puntos de acceso inalámbrico (`playbooks/quarterly/wireless_access_points.yml`) | Trimestral | Pendiente de mapeo | Pendiente |

`scripts_cron/` está vacío por ahora, a la espera de las ejecuciones programadas de las actividades anteriores.

### Detalle de los requisitos

**CHD SAD — 10.4.1.a / 10.4.1.b**
> Los siguientes registros de auditoría se revisan al menos una vez al día:
> - Todos los eventos de seguridad.
> - Registros de todos los componentes del sistema que almacenan, procesan o transmiten CHD y/o SAD.
> - Registros de todos los componentes críticos del sistema.
> - Registros de todos los servidores y componentes del sistema que realizan funciones de seguridad (por ejemplo, controles de seguridad de red, sistemas de detección de intrusiones/sistemas de prevención de intrusiones (IDS/IPS), servidores de autenticación).

**Contraseñas comprometidas — 8.6.3.a / 8.6.3.b / 8.6.3.c**
> Las contraseñas/frases de paso para cualquier cuenta de aplicación y de sistema están protegidas contra el uso indebido de la siguiente manera:
> - Las cuentas de sistema y de aplicación se cambian periódicamente (a una frecuencia definida en el análisis de riesgos específico de la entidad, el cual se desarrolla de acuerdo con todos los elementos especificados en el Requisito 12.3.1) y ante la sospecha o la confirmación de que estén comprometidas.
> - Las contraseñas/frases de acceso se construyen con la complejidad necesaria y apropiada para la frecuencia con la que la entidad cambia las contraseñas/frases de acceso.

**Fallas de infraestructura — 10.7.1.a / 10.7.1.b, 10.7.2.a / 10.7.2.b, 10.7.3.a / 10.7.3.b**

*10.7.1.a / 10.7.1.b (requisito adicional solo para proveedores de servicios):*
> Las fallas de los sistemas de control de seguridad críticos se detectan, alertan y abordan de inmediato, incluyendo entre otras, las fallas de los siguientes sistemas de control de seguridad críticos:
> - Controles de seguridad de la red
> - IDS/IPS
> - FIM
> - Soluciones antimalware
> - Controles de acceso físico
> - Controles de ingreso lógico
> - Mecanismos de registro de auditoría
> - Controles de segmentación (si se utilizan)

*10.7.2.a / 10.7.2.b:*
> Las fallas de los sistemas de control de seguridad críticos se detectan, alertan y abordan de inmediato, incluidas, entre otras, las fallas de los siguientes sistemas de control de seguridad críticos:
> - Controles de seguridad de la red
> - IDS/IPS
> - Cambiar los mecanismos de detección
> - Soluciones antimalware
> - Controles de acceso físico
> - Controles de ingreso lógico
> - Mecanismos de registro de auditoría
> - Controles de segmentación (si se utilizan)
> - Mecanismos de revisión del registro de auditoría
> - Herramientas de prueba de seguridad automatizadas (si se utilizan)

*10.7.3.a / 10.7.3.b:*
> Las fallas de cualquier sistema de control de seguridad crítico se responden con prontitud, incluidas, entre otras, las siguientes:
> - Restaurando las funciones de seguridad.
> - Identificando y documentando la duración (fecha y hora de principio a fin) de la falla de seguridad.
> - Identificando y documentando las causas de la falla y documentando el remedio requerido.
> - Identificando y abordando cualquier problema de seguridad que surgió durante la falla.
> - Determinando si se requieren más acciones como resultado de la falla de seguridad.
> - Implementando controles para evitar que se repita la causa de la falla.
> - Reanudación del monitoreo de los controles de seguridad.

**Registros requeridos — 10.4.2.a / 10.4.2.b**
> 10.4.2.a: Examinar las políticas y procedimientos de seguridad para verificar que existan procesos definidos para revisar periódicamente los registros de todos los demás componentes del sistema.
> 10.4.2.b: Examinar los resultados documentados de las revisiones de registros y entrevistar al personal para verificar que las revisiones de registros se realicen periódicamente.

### Detalle de implementación a nivel de plataforma

| Plataforma | Actividad | Estado |
|---|---|---|
| FortiGate | `system_events` | Implementado (script de recolección, parser, plantilla de reporte, tarea) |
| FortiGate | `system_events_7_days` | Implementado (script de recolección, parser, plantilla de reporte, tarea) |
| FortiGate | `security_events_and_forward_traffic` | Implementado (script de recolección, parser, plantillas de reporte, tarea) |
| FortiGate | `admin_login_failed` | Implementado (script de recolección, parser, plantilla de reporte, tarea, envío de reporte por correo) |
| FortiGate | `configuration_changes` | Implementado (script de recolección, parser, plantilla de reporte, tarea, envío de reporte por correo) |
| Check Point | `authentication failures` | Implementado (script contra la API de Infinity Portal, parser, tarea, envío de reporte por correo) |
| Check Point | `events_ips` | Implementado (script contra la API de Infinity Portal, parser, tarea, envío de reporte por correo) |
| Check Point | `events_ips_7_days` | Implementado (script contra la API de Infinity Portal, parser, tarea, envío de reporte por correo) |
| Check Point | `block-acceptance` | Implementado (script contra la API de Infinity Portal, parser, tarea, envío de reporte por correo) |
| Wazuh | integración local del SIEM | Pendiente |

El playbook diario `chd_sad.yml` ejecuta eventos de sistema de FortiGate y eventos IPS de Check Point. El playbook diario `compromised_passwords.yml` ejecuta fallos de autenticación de Check Point y fallos de inicio de sesión de administrador de FortiGate (ambos implementados). El playbook diario `infrastructure_failures.yml` ejecuta los cambios de configuración de FortiGate (implementado). El playbook semanal `change_detection.yml` ejecuta eventos de sistema de FortiGate y eventos IPS de Check Point de los últimos 7 días; `required_logs.yml` ejecuta eventos de seguridad/tráfico saliente de FortiGate y block-acceptance de Check Point de los últimos 7 días (ambos implementados). Todos los playbooks mensuales y trimestrales siguen siendo plantillas vacías.

Los roles de FortiGate dependen de utilidades compartidas en `roles/fortigate/common/` (`fortigate_ssh.sh` para la ejecución remota por CLI y `send_mail_report.sh` para el envío de evidencia por correo) y de `roles/fortigate/vars/vault.yml` para la configuración de correo, el cual debe completarse y cifrarse con Ansible Vault antes de usarse en producción. Los roles de Check Point se autentican contra la API de Infinity Portal Events usando las credenciales definidas en `roles/checkpoint/vars/vault.yml` (client ID, access key, endpoints de la API y configuración de correo), las cuales también deben completarse y cifrarse antes de usarse en producción.
