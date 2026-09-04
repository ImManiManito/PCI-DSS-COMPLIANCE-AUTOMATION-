# scripts_cron

*[Leer este documento en español](README.md)*

This directory contains the schedulable scripts to run the playbooks of
PCI-DSS-COMPLIANCE-AUTOMATION- according to their defined frequency.

## Available scripts

| Script              | Playbooks executed          | Execution condition                                 |
|---------------------|-----------------------------|-----------------------------------------------------|
| `run_daily.sh`      | `playbooks/daily/*.yml`     | Every time it is invoked                            |
| `run_weekly.sh`     | `playbooks/weekly/*.yml`    | Only on Mondays (`date +%u == 1`)                   |
| `run_monthly.sh`    | `playbooks/monthly/*.yml`   | Only on the 1st day of each month (`date +%d == 01`)|
| `run_quarterly.sh`  | `playbooks/quarterly/*.yml` | Only on January 1, April 1, July 1, and October 1   |

## Requirements

- Run on the Ansible controller (Linux/WSL/Git Bash environment).
- Have `ansible-playbook` available in `PATH`.
- Make the scripts executable:

  ```bash
  chmod +x scripts_cron/*.sh
  ```

## Ansible Vault usage

If sensitive variables are encrypted with Ansible Vault, create a file with the
Vault password (for example, `~/.vault_pass`) with restrictive permissions:

```bash
chmod 600 ~/.vault_pass
```

And export the environment variable before running or in the crontab:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=/secure/path/.vault_pass
```

## Cron configuration example

```cron
# Daily at 06:00
0 6 * * * /path/to/project/scripts_cron/run_daily.sh >> /path/to/project/logs/cron_daily.log 2>&1

# Weekly (Monday) at 06:30
30 6 * * * /path/to/project/scripts_cron/run_weekly.sh >> /path/to/project/logs/cron_weekly.log 2>&1

# Monthly (1st) at 07:00
0 7 1 * * /path/to/project/scripts_cron/run_monthly.sh >> /path/to/project/logs/cron_monthly.log 2>&1

# Quarterly (January 1, April 1, July 1, October 1) at 07:30
30 7 1 1,4,7,10 * /path/to/project/scripts_cron/run_quarterly.sh >> /path/to/project/logs/cron_quarterly.log 2>&1
```

> Note: although `run_weekly.sh`, `run_monthly.sh`, and `run_quarterly.sh`
> include their own date filtering logic, it is recommended to also set the
> restrictions in cron to avoid unnecessary executions.

## Logs

The scripts do not generate log files automatically; output is sent to
`stdout`/`stderr`. If you want to keep it in a file, redirect manually when
calling the script or in the cron configuration, for example:

```bash
./scripts_cron/run_daily.sh >> /path/to/logs/daily_$(date +%Y%m%d_%H%M%S).log 2>&1
```
