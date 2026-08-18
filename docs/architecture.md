*[Leer este documento en español](architecture.es.md)*

# Deployment Architecture

## Location of Ansible

For this project, Ansible runs **on the same asset that hosts the SIEM (Wazuh)**, instead of on a machine or asset dedicated exclusively to automation.

This decision reflects the infrastructure currently available for the project, and is the reason why the `wazuh/` role does not follow the same structure (`scripts/`, `tasks/`, `templates/`) as the other roles: since it runs locally on the SIEM itself, it does not require the remote connection (SSH) tasks that `checkpoint/` and `fortigate/` need.

### Ideal state vs. current state

| | Ideal state | Current project state |
|---|---|---|
| Ansible location | Dedicated virtual machine or asset, 100% reserved for automation | Same asset where the SIEM (Wazuh) runs |
| Isolation | Ansible separated from the systems it audits/collects from | Ansible and SIEM coexist on the same asset |
| Reason | Reduces risk, separates responsibilities, eases scaling | Infrastructure limitation for the current project scope |

This decision is documented formally to make clear that:

1. The recommended approach, and best practice, is to have a separate asset dedicated exclusively to Ansible.
2. For the current project scope, a mixed scheme is used: **Ansible + SIEM coexisting on the same asset**.
3. This decision should be revisited in the future if infrastructure allows it, migrating Ansible to an independent asset without affecting the logic of the playbooks, roles, or inventory already defined.

## Resulting security considerations

Since Ansible and the SIEM coexist on the same asset:

- Credentials managed with Ansible Vault must be protected with special care, since a compromise of the asset would affect both the automation and the SIEM itself.
- Access to the asset must be restricted following the principle of least privilege, since it concentrates two critical functions.
- It is recommended to keep the asset up to date and limit exposed services, minimizing the attack surface shared between Ansible and the SIEM.
