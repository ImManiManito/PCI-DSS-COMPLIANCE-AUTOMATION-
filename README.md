*[Leer este documento en español](README.es.md)*

# PCI-DSS-COMPLIANCE-AUTOMATION-

PCI-DSS-COMPLIANCE-AUTOMATION- is an automation project designed to streamline the execution and monitoring of activities related to the PCI DSS (Payment Card Industry Data Security Standard).

The project uses Ansible as its primary automation platform and integrates several security technologies, including FortiGate, Check Point, and Wazuh, to collect security information, process events, and generate standardized compliance evidence.

Activities are organized according to their execution frequency:

Daily -- Weekly -- Monthly -- Quarterly

The project architecture is designed to keep each activity organized and independent by separating execution playbooks, Ansible tasks, and the scripts used to collect and process security information.

playbooks/
    Activities organized by execution frequency.

roles/
    Platform-specific automation.

files/
    Scripts, parsers, and auxiliary files for each activity.

common/
    Components shared across multiple activities.

inventory/
    Infrastructure inventory.

scripts_cron/
    Scheduled and automated executions.

The project also uses Ansible Vault to protect credentials, API keys, and other sensitive information, ensuring that secrets are not stored directly in the source code.

## Deployment architecture

Ideally, Ansible should run on a dedicated virtual machine or asset separate from the SIEM. For this project, due to current infrastructure constraints, Ansible runs on the same asset that hosts the SIEM (Wazuh). See [docs/architecture.md](docs/architecture.md) (also available [in Spanish](docs/architecture.es.md)) for details and the security considerations that follow from this decision.

The inventory (`inventory/hosts.ini`) currently defines three groups: `fortigates` (remote, over SSH), `checkpoint` (local connection), and `wazuh` (local connection).

The main goal of this initiative is to reduce manual processes, improve the consistency and reliability of security activities, and facilitate the generation of evidence for PCI DSS compliance reviews and audits.

## Implementation status

Not every activity is implemented yet. The table below reflects the current state of the repository.

| Platform | Activity | Status |
|---|---|---|
| FortiGate | `system_events` | Implemented (collection script, parser, report template, task) |
| FortiGate | `system_events_7_days` | Implemented (collection script, parser, report template, task) |
| FortiGate | `security_events_and_forward_traffic` | Implemented (collection script, parser, report templates, task) |
| FortiGate | `admin_login_failed` | Pending |
| FortiGate | `configuration_changes` | Pending |
| Check Point | `authentication failures` | Implemented (Infinity Portal Events API script, parser, task, email report) |
| Check Point | `events_ips` | Implemented (Infinity Portal Events API script, parser, task, email report) |
| Check Point | `block-acceptance`, `checkpoint_audits` | Pending (folder structure only) |
| Wazuh | local SIEM integration | Pending |

Daily playbook `chd_sad.yml` runs FortiGate system events and Check Point IPS events. Daily playbook `compromised_passwords.yml` runs Check Point authentication failures (implemented) and FortiGate admin login failed (still pending, empty task). Daily playbook `infrastructure_failures.yml` references FortiGate configuration changes, which is still pending (empty task). Weekly playbook `change_detection.yml` runs FortiGate system events and security/forward-traffic events over the last 7 days; `required_logs.yml` is still an empty placeholder. All monthly and quarterly playbooks remain empty placeholders. `scripts_cron/` is also currently empty, pending the scheduled executions for the activities above.

FortiGate roles rely on shared helpers under `roles/fortigate/common/` (`fortigate_ssh.sh` for remote CLI execution and `send_mail_report.sh` for emailing evidence) and on `roles/fortigate/vars/vault.yml` for mail settings, which must be filled in and encrypted with Ansible Vault before use in production. Check Point roles authenticate against the Infinity Portal Events API using credentials defined in `roles/checkpoint/vars/vault.yml` (client ID, access key, API endpoints, and mail settings), which must also be filled in and encrypted before production use.
