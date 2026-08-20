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

## PCI DSS compliance mapping

The table below maps each activity (playbook) to the PCI DSS requirements it satisfies and the frequency at which it runs.

| Activity (playbook) | Frequency | PCI DSS requirements | Status |
|---|---|---|---|
| CHD SAD (`playbooks/daily/chd_sad.yml`) | Daily | 10.4.1.a, 10.4.1.b | Implemented |
| Compromised Passwords (`playbooks/daily/compromised_passwords.yml`) | Daily | 8.6.3.a, 8.6.3.b, 8.6.3.c | Implemented |
| Infrastructure Failures (`playbooks/daily/infrastructure_failures.yml`) | Daily | 10.7.1.a, 10.7.1.b, 10.7.2.a, 10.7.2.b, 10.7.3.a, 10.7.3.b | Implemented |
| Change Detection (`playbooks/weekly/change_detection.yml`) | Weekly | Pending mapping | Implemented |
| Required Logs (`playbooks/weekly/required_logs.yml`) | Weekly | 10.4.2.a, 10.4.2.b | Implemented |
| Access Logs (`playbooks/monthly/access_logs.yml`) | Monthly | Pending mapping | Pending |
| Account Activity (`playbooks/monthly/account_activity.yml`) | Monthly | Pending mapping | Pending |
| Periodic Evaluations (`playbooks/monthly/periodic_evaluations.yml`) | Monthly | Pending mapping | Pending |
| Privileged Accounts (`playbooks/monthly/privileged_accounts.yml`) | Monthly | Pending mapping | Pending |
| Available Logs (`playbooks/quarterly/available_logs.yml`) | Quarterly | Pending mapping | Pending |
| Password Changes (`playbooks/quarterly/password_changes.yml`) | Quarterly | Pending mapping | Pending |
| Review of Suites and Protocols (`playbooks/quarterly/review_of_suites_and_protocols.yml`) | Quarterly | Pending mapping | Pending |
| Wireless Access Points (`playbooks/quarterly/wireless_access_points.yml`) | Quarterly | Pending mapping | Pending |

`scripts_cron/` is currently empty, pending the scheduled executions for the activities above.

### Requirement detail

**CHD SAD — 10.4.1.a / 10.4.1.b**
> The following audit logs are reviewed at least once daily:
> - All security events.
> - Logs of all system components that store, process, or transmit CHD and/or SAD.
> - Logs of all critical system components.
> - Logs of all servers and system components that perform security functions (for example, network security controls, intrusion-detection/intrusion-prevention systems (IDS/IPS), authentication servers).

**Compromised Passwords — 8.6.3.a / 8.6.3.b / 8.6.3.c**
> Passwords/passphrases for any application and system accounts are protected against misuse as follows:
> - System and application accounts are changed periodically (at the frequency defined in the entity's targeted risk analysis, performed according to all elements specified in Requirement 12.3.1) and upon suspicion or confirmation of compromise.
> - Passwords/passphrases are constructed with sufficient complexity appropriate for how frequently the entity changes the passwords/passphrases.

**Infrastructure Failures — 10.7.1.a / 10.7.1.b, 10.7.2.a / 10.7.2.b, 10.7.3.a / 10.7.3.b**

*10.7.1.a / 10.7.1.b (additional requirement for service providers only):*
> Failures of critical security control systems are detected, alerted, and addressed promptly, including but not limited to failure of the following critical security control systems:
> - Network security controls
> - IDS/IPS
> - FIM
> - Anti-malware solutions
> - Physical access controls
> - Logical access controls
> - Audit logging mechanisms
> - Segmentation controls (if used)

*10.7.2.a / 10.7.2.b:*
> Failures of critical security control systems are detected, alerted, and addressed promptly, including but not limited to failure of the following critical security control systems:
> - Network security controls
> - IDS/IPS
> - Change-detection mechanisms
> - Anti-malware solutions
> - Physical access controls
> - Logical access controls
> - Audit logging mechanisms
> - Segmentation controls (if used)
> - Audit log review mechanisms
> - Automated security testing tools (if used)

*10.7.3.a / 10.7.3.b:*
> Failures of any critical security control systems are responded to promptly, including but not limited to:
> - Restoring security functions.
> - Identifying and documenting the duration (date and time from start to end) of the security failure.
> - Identifying and documenting the cause(s) of failure and documenting required remediation.
> - Identifying and addressing any security issues that arose during the failure.
> - Determining whether further actions are required as a result of the security failure.
> - Implementing controls to prevent the cause of the failure from reoccurring.
> - Resuming monitoring of security controls.

**Required Logs — 10.4.2.a / 10.4.2.b**
> 10.4.2.a: Examine security policies and procedures to verify that processes are defined for reviewing logs of all other system components periodically.
> 10.4.2.b: Examine documented results of log reviews and interview personnel to verify that log reviews are performed periodically.

Daily playbook `chd_sad.yml` runs FortiGate system events and Check Point IPS events. Daily playbook `compromised_passwords.yml` runs Check Point authentication failures and FortiGate admin login failed (both implemented). Daily playbook `infrastructure_failures.yml` runs FortiGate configuration changes (implemented). Weekly playbook `change_detection.yml` runs FortiGate system events and Check Point IPS events over the last 7 days; `required_logs.yml` runs FortiGate security/forward-traffic events and Check Point block-acceptance over the last 7 days (both implemented). All monthly and quarterly playbooks remain empty placeholders.

FortiGate roles rely on shared helpers under `roles/fortigate/common/` (`fortigate_ssh.sh` for remote CLI execution and `send_mail_report.sh` for emailing evidence) and on `roles/fortigate/vars/vault.yml` for mail settings, which must be filled in and encrypted with Ansible Vault before use in production. Check Point roles authenticate against the Infinity Portal Events API using credentials defined in `roles/checkpoint/vars/vault.yml` (client ID, access key, API endpoints, and mail settings), which must also be filled in and encrypted before production use.
