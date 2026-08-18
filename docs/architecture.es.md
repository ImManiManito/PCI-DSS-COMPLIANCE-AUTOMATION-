*[Read this document in English](architecture.md)*

# Arquitectura de despliegue

## Ubicación de Ansible

Para este proyecto, Ansible se ejecuta **dentro del mismo activo que aloja el SIEM (Wazuh)**, en lugar de sobre una máquina o activo dedicado exclusivamente a la automatización.

Esta decisión responde a las condiciones actuales de infraestructura disponibles para el proyecto y es la razón por la cual el rol `wazuh/` no sigue la misma estructura (`scripts/`, `tasks/`, `templates/`) que el resto de los roles: al ejecutarse en local sobre el propio SIEM, no requiere las tareas de conexión remota (SSH) que sí necesitan `checkpoint/` y `fortigate/`.

### Estado ideal vs. estado actual

| | Estado ideal | Estado actual del proyecto |
|---|---|---|
| Ubicación de Ansible | Máquina virtual o activo independiente, dedicado 100% a la automatización | Mismo activo donde corre el SIEM (Wazuh) |
| Aislamiento | Ansible separado de los sistemas que audita/recolecta | Ansible y SIEM conviven en el mismo activo |
| Motivo | Reduce riesgo, separa responsabilidades, facilita escalado | Limitación de infraestructura disponible para el proyecto |

Se documenta esta decisión de manera formal para dejar constancia de que:

1. Lo recomendado, y la mejor práctica, es contar con un activo separado exclusivo para Ansible.
2. Para el alcance actual del proyecto se utiliza un esquema mixto: **Ansible + SIEM conviviendo en el mismo activo**.
3. Esta decisión debe revisarse a futuro si la infraestructura lo permite, migrando Ansible a un activo independiente sin afectar la lógica de playbooks, roles ni inventario ya definidos.

## Consideraciones de seguridad derivadas

Al convivir Ansible y el SIEM en el mismo activo:

- Las credenciales gestionadas con Ansible Vault deben protegerse con especial cuidado, dado que un compromiso del activo afectaría tanto la automatización como el propio SIEM.
- El acceso al activo debe restringirse siguiendo el principio de mínimo privilegio, ya que concentra dos funciones críticas.
- Se recomienda mantener actualizado el activo y limitar los servicios expuestos, minimizando la superficie de ataque compartida entre Ansible y el SIEM.
