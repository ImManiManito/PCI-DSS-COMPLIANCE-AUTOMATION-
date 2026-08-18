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

El objetivo principal de esta iniciativa es reducir los procesos manuales, mejorar la consistencia y confiabilidad de las actividades de seguridad, y facilitar la generación de evidencia para las revisiones y auditorías de cumplimiento PCI DSS.
