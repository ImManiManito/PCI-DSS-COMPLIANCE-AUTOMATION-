*[Read this document in English](README.md)*

# PCI-DSS-COMPLIANCE-AUTOMATION-

PCI-DSS-COMPLIANCE-AUTOMATION- es un proyecto de automatización diseñado para agilizar la ejecución y el monitoreo de actividades relacionadas con el PCI DSS (Payment Card Industry Data Security Standard).

El proyecto utiliza Ansible como su plataforma principal de automatización e integra varias tecnologías de seguridad, incluyendo FortiGate, Check Point y Wazuh, para recolectar información de seguridad, procesar eventos y generar evidencia estandarizada de cumplimiento.

Las actividades se organizan según su frecuencia de ejecución:

Diario -- Semanal -- Mensual -- Trimestral

La arquitectura del proyecto está diseñada para mantener cada actividad organizada e independiente, separando los playbooks de ejecución, las tareas de Ansible y los scripts utilizados para recolectar y procesar la información de seguridad.

playbooks/
    Actividades organizadas por frecuencia de ejecución (diaria, semanal, mensual, trimestral).

roles/
    Automatización específica por plataforma (fortigate/, checkpoint/, wazuh/). Cada rol de actividad normalmente contiene:
    - scripts/ -- scripts de recolección y parseo.
    - tasks/ -- definiciones de tareas de Ansible.
    - templates/ -- plantillas Jinja2 para los reportes.
    - common/ -- utilidades compartidas entre las actividades de la plataforma (por ejemplo, ejecución por SSH y envío de correo).
    - vars/ -- variables cifradas con Ansible Vault (credenciales, endpoints de API, configuración de correo).

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

| Requisitos PCI DSS | Actividad (playbook) | Periodicidad | Estado |
|---|---|---|---|
| 10.4.1.a, 10.4.1.b, 10.6.1 | CHD SAD (`playbooks/daily/chd_sad.yml`) | Diaria | Implementado |
| 8.6.3.a, 8.6.3.b, 8.6.3.c | Contraseñas comprometidas (`playbooks/daily/compromised_passwords.yml`) | Diaria | Implementado |
| 10.7.1.a, 10.7.1.b, 10.7.2.a, 10.7.2.b, 10.7.3.a, 10.7.3.b | Fallas de infraestructura (`playbooks/daily/infrastructure_failures.yml`) | Diaria | Implementado |
| 11.5.2.a, 11.5.2.b, 10.6.1 | Detección de cambios (`playbooks/weekly/change_detection.yml`) | Semanal | Implementado |
| 10.4.2.a, 10.4.2.b | Registros requeridos (`playbooks/weekly/required_logs.yml`) | Semanal | Implementado |
| 7.2.5.1.a, 7.2.5.1.b, 7.2.5.1.c | Registros de acceso (`playbooks/monthly/access_logs.yml`) | Mensual | Pendiente |
| 8.2.6 | Actividad de cuentas (`playbooks/monthly/account_activity.yml`) | Mensual | Pendiente |
| 10.4.2.1.a, 10.4.2.1.b | Evaluaciones periódicas (`playbooks/monthly/periodic_evaluations.yml`) | Mensual | Pendiente |
| 7.2.4.a, 7.2.4.b | Cuentas privilegiadas (`playbooks/monthly/privileged_accounts.yml`) | Mensual | Pendiente |
| 10.5.1.a, 10.5.1.b, 10.5.1.c | Registros disponibles (`playbooks/quarterly/available_logs.yml`) | Trimestral | Pendiente |
| 8.3.9, 8.3.10.1 | Cambios de contraseña (`playbooks/quarterly/password_changes.yml`) | Trimestral | Pendiente |
| 12.3.3 | Revisión de suites y protocolos (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Trimestral | Pendiente |
| 11.2.1.a, 11.2.1.b, 11.2.1.c, 11.2.1.d | Puntos de acceso inalámbrico (`playbooks/quarterly/wireless_access_points.yml`) | Trimestral | Pendiente |

`scripts_cron/` está vacío por ahora, a la espera de las ejecuciones programadas de las actividades anteriores.

### Detalle de los requisitos

**CHD SAD — 10.4.1.a / 10.4.1.b**
> Los siguientes registros de auditoría se revisan al menos una vez al día:
> - Todos los eventos de seguridad.
> - Registros de todos los componentes del sistema que almacenan, procesan o transmiten CHD y/o SAD.
> - Registros de todos los componentes críticos del sistema.
> - Registros de todos los servidores y componentes del sistema que realizan funciones de seguridad (por ejemplo, controles de seguridad de red, sistemas de detección de intrusiones/sistemas de prevención de intrusiones (IDS/IPS), servidores de autenticación).
>
> Adicionalmente, el rol de Wazuh `chd_sad_review` ahora recolecta las alertas relacionadas con CHD/SAD desde `alerts.json` (filtradas por el grupo de reglas/etiqueta de control `10.6.1`) para complementar la evidencia diaria de FortiGate y Check Point.

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

**Detección de cambios — 11.5.2.a / 11.5.2.b**
> Un mecanismo de detección de cambios (por ejemplo, herramientas de monitoreo de integridad de archivos) se despliega como sigue:
> - Para alertar al personal sobre modificaciones no autorizadas (incluyendo cambios, adiciones y eliminaciones) de archivos críticos.
> - Para realizar comparaciones de archivos críticos al menos una vez por semana.
>
> Adicionalmente, el rol de Wazuh `chd_sad_review_7_days` ahora recolecta las alertas relacionadas con CHD/SAD de los últimos 7 días (filtradas por el grupo de reglas/etiqueta de control `10.6.1`) para complementar la evidencia semanal de FortiGate y Check Point.

**Cuentas privilegiadas — 7.2.4.a / 7.2.4.b**
> Todas las cuentas de usuario y los privilegios de acceso relacionados, incluyendo las cuentas de terceros/proveedores, se revisan de la siguiente manera:
> - Al menos una vez cada seis meses.
> - Para asegurarse de que las cuentas de usuario y el acceso sigan siendo apropiados según la función del trabajo.
> - Se aborda cualquier acceso inadecuado.
> - La gerencia reconoce que el acceso sigue siendo apropiado.

**Registros de acceso — 7.2.5.1.a / 7.2.5.1.b / 7.2.5.1.c**
> Todo el acceso de aplicaciones y cuentas del sistema y los privilegios de acceso relacionados se revisan de la siguiente manera:
> - Periódicamente (a una frecuencia definida en el análisis de riesgos específico de la entidad, el cual se desarrolla de acuerdo con todos los elementos especificados en el Requisito 12.3.1).
> - El acceso a la aplicación/sistema sigue siendo apropiado para la función que se está realizando.
> - Se aborda cualquier acceso inadecuado.
> - La gerencia reconoce que el acceso sigue siendo apropiado.

**Actividad de cuentas — 8.2.6**
> Las cuentas de usuario inactivas se eliminan o inhabilitan dentro de los 90 días de inactividad.

**Registros disponibles — 10.5.1.a / 10.5.1.b / 10.5.1.c**
> Conserve el historial de los registros de auditoría durante 12 meses como mínimo, teniendo al menos los tres últimos meses inmediatamente disponibles para su análisis.

**Revisión de suites y protocolos — 12.3.3**
> Los protocolos y conjuntos de cifrado criptográfico en uso se documentan cada 12 meses y revisan al menos una vez cada 3 meses, incluyendo al menos lo siguiente:
> - Un inventario actualizado de todos los protocolos y conjuntos de cifrado criptográfico en uso, incluyendo su propósito y dónde se utilizan.
> - Monitoreo activo de las tendencias de la industria con respecto a la viabilidad continua de todos los protocolos y conjuntos de cifrado criptográfico en uso.
> - Una estrategia documentada para responder a los cambios.

**Evaluaciones periódicas — 10.4.2.1.a / 10.4.2.1.b**
> La frecuencia de las evaluaciones periódicas de los componentes del sistema identificados (no definidos en el Requisito 10.4.1) se define en el análisis de riesgo específico de la entidad, el cual se realiza de acuerdo con todos los elementos especificados en el Requisito 12.3.1.

**Cambios de contraseña — 8.3.9 / 8.3.10.1**
> 8.3.9: Si las contraseñas/frases de paso se utilizan como el único factor de autenticación para el acceso del usuario (es decir, en cualquier implementación de autenticación de factor único), entonces:
> - Las contraseñas/frases de paso se cambian al menos una vez cada 90 días,
> - La postura de seguridad de las cuentas se analiza dinámicamente y el acceso a los recursos en tiempo real se determina automáticamente de acuerdo a dicha postura de seguridad.
>
> 8.3.10.1 (requisito adicional solo para proveedores de servicios): Si las contraseñas/frases de paso se utilizan como el único factor de autenticación para el acceso del usuario del cliente (es decir, en cualquier implementación de autenticación de factor único), entonces:
> - Las contraseñas/frases de paso se cambian al menos una vez cada 90 días,
> - La postura de seguridad de las cuentas se analiza dinámicamente y el acceso a los recursos en tiempo real se determina automáticamente de acuerdo a dicha postura.

**Puntos de acceso inalámbrico — 11.2.1.a / 11.2.1.b / 11.2.1.c / 11.2.1.d**
> Los puntos de acceso inalámbricos autorizados y no autorizados se gestionan de la siguiente manera:
> - Se comprueba la existencia de puntos de acceso inalámbricos (Wi-Fi).
> - Se detectan e identifican todos los puntos de acceso inalámbricos autorizados y no autorizados.
> - La verificación, detección e identificación ocurre al menos cada tres meses.
> - Si se utiliza la supervisión automatizada, se notifica al personal mediante la generación de alertas.

El proyecto se encuentra en una etapa de implementación progresiva, con actividades distribuidas de acuerdo con su frecuencia de ejecución y su relación con los controles establecidos por PCI DSS. Las actividades actualmente implementadas permiten reducir la dependencia de procesos manuales y establecer un enfoque más consistente para la revisión, seguimiento y generación de evidencia de seguridad.

A futuro, la iniciativa contempla ampliar la cobertura de las actividades pendientes, fortalecer la estandarización de los procesos y mantener una evolución continua conforme a las necesidades de seguridad y cumplimiento de la organización. La documentación técnica y los detalles específicos de implementación se mantienen separados de este documento para facilitar su consulta y mantenimiento.

Cabe aclarar que este proyecto solo se enfoca en ciertos puntos de la auditoria PCI DSS 