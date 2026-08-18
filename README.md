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

Ideally, Ansible should run on a dedicated virtual machine or asset separate from the SIEM. For this project, due to current infrastructure constraints, Ansible runs on the same asset that hosts the SIEM (Wazuh). See [docs/architecture.md](docs/architecture.md) for details and the security considerations that follow from this decision.

The main goal of this initiative is to reduce manual processes, improve the consistency and reliability of security activities, and facilitate the generation of evidence for PCI DSS compliance reviews and audits.
