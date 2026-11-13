*[Leer este documento en español](README.es.md)*

# PCI DSS Compliance Automation

This repository contains an Ansible-based automation framework for recurring PCI DSS security review activities, evidence collection, and operational reporting. The project is built around a modular design: each control is organized into a playbook, one or more platform-specific roles, and supporting scripts/templates used to gather and normalize information from FortiGate, Check Point, and Wazuh.

## Current project state

The project is in an active but incremental implementation stage. The repository includes the main automation flow and the scheduled execution layer. The current state is:

- Daily controls: implemented and operational.
- Weekly controls: implemented and scheduled.
- Monthly controls: defined in the repository and pending completion or validation.
- Quarterly controls: defined, with active functionality for some controls and others still pending.

## Repository structure

```text
.
├── ansible.cfg                # Ansible global configuration
├── inventory/
│   └── hosts.ini             # Inventory groups for FortiGate, Check Point, and Wazuh
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
│   └── *.sh                  # Entry points for scheduled execution
├── docs/
│   ├── architecture.md
│   └── architecture.es.md
├── README.md
├── README.es.md
└── vars/
```

## Control coverage and status

| PCI DSS scope | Activity | Frequency | Status |
|---|---|---|---|
| 10.2.4, 10.2.7, 10.4.1.a, 10.4.1.b, 10.6.1 | CHD SAD (`playbooks/daily/chd_sad.yml`) | Daily | Implemented |
| 8.6.3.a, 8.6.3.b, 8.6.3.c | Compromised Passwords (`playbooks/daily/compromised_passwords.yml`) | Daily | Implemented |
| 10.7.1.a, 10.7.1.b, 10.7.2.a, 10.7.2.b, 10.7.3.a, 10.7.3.b | Infrastructure Failures (`playbooks/daily/infrastructure_failures.yml`) | Daily | Implemented |
| 10.2.4, 10.2.7, 10.6.1, 11.5.2.a, 11.5.2.b | Change Detection (`playbooks/weekly/change_detection.yml`) | Weekly | Implemented |
| 10.4.2.a, 10.4.2.b | Required Logs (`playbooks/weekly/required_logs.yml`) | Weekly | Implemented |
| 7.2.5.1.a, 7.2.5.1.b, 7.2.5.1.c | Access Logs (`playbooks/monthly/access_logs.yml`) | Monthly | Defined / pending |
| 8.2.6 | Account Activity (`playbooks/monthly/account_activity.yml`) | Monthly | Defined / pending |
| 10.4.2.1.a, 10.4.2.1.b | Periodic Evaluations (`playbooks/monthly/periodic_evaluations.yml`) | Monthly | Defined / pending |
| 7.2.4.a, 7.2.4.b | Privileged Accounts (`playbooks/monthly/privileged_accounts.yml`) | Monthly | Defined / pending |
| 10.5.1.a, 10.5.1.b, 10.5.1.c | Available Logs (`playbooks/quarterly/available_logs.yml`) | Quarterly | Defined / pending |
| 8.3.9, 8.3.10.1 | Password Changes (`playbooks/quarterly/password_changes.yml`) | Quarterly | Implemented |
| 12.3.3 | Review of Suites and Protocols (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Quarterly | Defined / pending |
| 11.2.1.a, 11.2.1.b, 11.2.1.c, 11.2.1.d | Wireless Access Points (`playbooks/quarterly/wireless_access_points.yml`) | Quarterly | Defined / pending |

## Platform components

The automation is organized by technology:

- `roles/fortigate/`: collection and parsing of logs and events from FortiGate appliances, including configuration changes, system events, traffic and web filter review, and password-change workflows.
- `roles/checkpoint/`: collection and parsing of Check Point events such as authentication failures, block acceptance, and IPS-related activity.
- `roles/wazuh/`: local Wazuh-based review of security events and alert correlation for CHD/SAD analyses and weekly evidence collection.

Each role generally contains `scripts/`, `tasks/`, and `templates/` folders plus helper logic for mail delivery and SSH remote execution when required.

## Deployment architecture

The project currently assumes that Ansible executes on the same host as the SIEM, specifically Wazuh. This is an infrastructure constraint rather than the target ideal state. For the technical reasoning and the security implications of this design, see [docs/architecture.md](docs/architecture.md).

The inventory file (`inventory/hosts.ini`) defines the following groups:

- `fortigates`: remote connection via SSH.
- `checkpoint`: local execution.
- `wazuh`: local execution.

## Secret handling and automation execution

The project uses Ansible Vault to protect credentials, API endpoints, and operational settings. Sensitive values are not kept in plain text in the source tree. The default configuration expects the vault password to be stored in `~/.ansible/.vault_pass` and reads it automatically from `ansible.cfg`.

Scheduled execution is supported through the scripts in `scripts_cron/`:

- `run_daily.sh`
- `run_weekly.sh`
- `run_monthly.sh`
- `run_quarterly.sh`

These scripts are designed to execute the corresponding playbooks according to the configured frequency and to integrate with cron-based scheduling.

See [scripts_cron/README.md](scripts_cron/README.md) for examples and operational details.

## Example usage

```bash
ansible-playbook playbooks/daily/chd_sad.yml
ansible-playbook playbooks/weekly/change_detection.yml
./scripts_cron/run_daily.sh
./scripts_cron/run_weekly.sh
```

## Scope note

This repository focuses on specific PCI DSS security review controls and evidence collection workflows. It is not a full enterprise compliance platform, but a structured and repeatable automation baseline for the controls currently implemented or under development.
