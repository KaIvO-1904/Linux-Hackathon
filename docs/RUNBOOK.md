# University VM Runbook

Use this runbook on the approved Ubuntu Server VM, not Kali WSL. Commands marked **CAUTION** change system configuration. Commands marked **DATA CHANGE** create, archive, or remove project data. Keep the VM console available when changing SSH or firewall settings.

## 1. Install dependencies and project files

From the extracted project folder:

```bash
sudo ./scripts/install_dependencies.sh
sudo ./scripts/install_project.sh
```

The first command uses Ubuntu's package manager to install rsyslog, Cron, UFW, LVM2, filesystem, and archive tools. The second copies files to `/opt/smartcity` and creates `/srv/smartcity` project folders. They do not configure logging, Cron, or the firewall yet.

## 2. Inspect storage and prepare the LVM archive filesystem

```bash
sudo /opt/smartcity/scripts/inspect_storage.sh
```

Identify a dedicated, empty data disk from the output. Never guess a device name such as `/dev/sdb`; confirm its size, filesystem/signature, and mount status. If the VM has no separate data disk, ask the instructor whether one can be attached. The LVM setup script has a dry-run mode by default:

```bash
sudo /opt/smartcity/scripts/setup_lvm_storage.sh --device /dev/DEVICE
```

Replace `/dev/DEVICE` with the confirmed path from `lsblk`; do not paste the placeholder literally.

Only after confirming the exact device is disposable, run with `--apply`. It will ask you to type the device path before creating a PV/VG/LV, formatting ext4, and mounting it at `/srv/smartcity/archives`. **This erases all data on the selected disk. Never point it at the Ubuntu system disk.**

```bash
sudo /opt/smartcity/scripts/setup_lvm_storage.sh --device /dev/DEVICE --apply
```

Verify the LVM and mount:

```bash
sudo pvs
sudo vgs
sudo lvs
findmnt /srv/smartcity/archives
df -hP /srv/smartcity/archives
```

The logical volume initially uses 80% of the volume group to leave free extents for a growth demonstration. After creating some archives, the optional expansion script can use the remaining free space:

```bash
sudo /opt/smartcity/scripts/extend_lvm_storage.sh
sudo /opt/smartcity/scripts/extend_lvm_storage.sh --apply
```

The second command asks for confirmation before extending the filesystem. It does not reduce or delete data.

## 3. Create department groups, demo accounts, and folders

```bash
sudo /opt/smartcity/scripts/setup_departments.sh
sudo /opt/smartcity/scripts/create_demo_accounts.sh
getent group traffic safety water utilities
ls -ld /srv/smartcity/logs/*
sudo /opt/smartcity/scripts/verify_department_access.sh
```

The setup and demo-account scripts create the department folders, groups, and non-login accounts. The access-check script verifies that each demo account can write only to its own department folder. The demo accounts cannot log in interactively and have no passwords. Add an existing approved account to its department group if needed, for example:

```bash
sudo /opt/smartcity/scripts/add_department_user.sh alice traffic
```

The user must sign out and back in before the new supplementary group is reflected in their login session. Verify the result with `id alice`.

## 4. Configure local department log routing

```bash
sudo /opt/smartcity/scripts/configure_rsyslog.sh
sudo systemctl status --no-pager rsyslog
```

This installs rules mapping facilities `local0` through `local3` to traffic, safety, water, and utilities log files. It preserves a dated backup of any existing configuration file it replaces and validates the rsyslog configuration before restart.

## 5. Send and verify demo messages

```bash
sudo /opt/smartcity/scripts/send_demo_logs.sh
sudo /opt/smartcity/scripts/verify_logs.sh
```

These are local simulated department messages. They demonstrate routing, but do not prove remote syslog reception from separate machines.

## 6. Generate and archive reports

```bash
/opt/smartcity/scripts/health_report.sh
sudo /opt/smartcity/scripts/health_report.sh --output /srv/smartcity/reports/health-latest.txt
sudo /opt/smartcity/scripts/archive_logs.sh
```

The archive command defaults to a dry run and lists files older than seven days. For a real archive, review its output, then run:

```bash
sudo /opt/smartcity/scripts/archive_logs.sh --execute
```

Original log files are retained. To inspect an archive:

```bash
tar -tzf /srv/smartcity/archives/smartcity-logs-<timestamp>.tar.gz
gzip -t /srv/smartcity/archives/smartcity-logs-<timestamp>.tar.gz
```

Replace `<timestamp>` with the actual filename shown by `ls -l /srv/smartcity/archives`.

## 7. Back up and restore

```bash
sudo /opt/smartcity/scripts/backup_project.sh
ls -lh /srv/smartcity/backups
```

Restore a backup into a new, empty verification directory. Replace the placeholder with the actual filename:

```bash
sudo /opt/smartcity/scripts/restore_project.sh \
  --archive /srv/smartcity/backups/smartcity-backup-<timestamp>.tar.gz \
  --target /tmp/smartcity-restore
```

The restore script refuses to extract into a non-empty directory. Inspect the result under `/tmp/smartcity-restore` and compare it with the source.

## 8. Install Cron jobs

```bash
sudo /opt/smartcity/scripts/install_cron.sh
sudo cat /etc/cron.d/smartcity
sudo systemctl status --no-pager cron
```

The schedule runs the health report daily at 06:00, archives logs older than seven days at 01:00, removes archives older than thirty days at 01:20, and creates a backup at 02:00. Use `grep smartcity /var/log/syslog` or inspect `/srv/smartcity/reports` and `/srv/smartcity/backups` to verify actual runs.

## 9. Firewall (only if required)

On the VM console, inspect the proposed policy first:

```bash
sudo /opt/smartcity/scripts/configure_firewall.sh
```

The policy defaults to denying inbound traffic, allowing outbound traffic, and allowing SSH. Local simulated logging does not require opening syslog port 514. Apply only after confirming the network and keeping console access available:

```bash
sudo /opt/smartcity/scripts/configure_firewall.sh --apply
sudo ufw status numbered
```

This demo's firewall script does not open port 514. Configure remote syslog only if the instructor requires it and after the listener configuration and private network details are confirmed.

## Evidence checklist

- `id` output for a department user and `ls -ld` output for department directories.
- `systemctl status rsyslog` and the four routed log files with demo messages.
- Health report showing actual VM values.
- Archive listing and `gzip -t` result.
- Backup file listing and restored files in the separate restore directory.
- Cron configuration plus evidence of at least one job execution.
- UFW status if firewall configuration is required.

Record actual outputs and note any skipped or failed verification honestly.
