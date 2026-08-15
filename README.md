# PCI-DSS-COMPLIANCE-AUTOMATION-

Es un proyecto de automatización orientado a facilitar la ejecución y seguimiento de actividades relacionadas con el cumplimiento del estándar PCI DSS (Payment Card Industry Data Security Standard).

El proyecto utiliza Ansible como plataforma principal de automatización e integra diferentes tecnologías de seguridad, entre ellas FortiGate, Check Point y Wazuh, para recopilar información, procesar eventos y generar evidencias de seguridad de manera estandarizada.

Las actividades se organizan de acuerdo con su periodicidad:

Daily
Weekly
Monthly
Quarterly

La arquitectura está diseñada para mantener cada actividad organizada e independiente, separando los playbooks de ejecución, las tareas de Ansible y los scripts utilizados para la extracción y procesamiento de información.

playbooks/
    Actividades organizadas por periodicidad.

roles/
    Automatizaciones específicas de cada plataforma.

files/
    Scripts, parsers y archivos auxiliares de cada actividad.

common/
    Componentes compartidos entre actividades.

inventory/
    Inventario de infraestructura.

scripts_cron/
    Ejecuciones automatizadas y programadas.

El proyecto también incorpora Ansible Vault para proteger credenciales, API Keys y otra información sensible, evitando que estos datos sean almacenados directamente en el código fuente.

El propósito de esta iniciativa es reducir procesos manuales, mejorar la consistencia de las actividades de seguridad y facilitar la generación de evidencias que puedan ser utilizadas durante procesos de revisión y auditoría de cumplimiento PCI DSS.
