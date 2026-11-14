# Smart City Command Centre
## Linux System Administration — Semester End Examination Project Report

**Examination date:** 14 November 2026  
**Programme:** IT Core / AR/VR / DA — V Semester  
**Team:** [Team name]  
**Members / registration numbers:** [Add all names and IDs]  
**Ubuntu Server version / hostname:** [Record from the VM]  
**Submission status:** Prepared project bundle; execution results must be completed from the team's VM.

> **Evidence integrity:** The project files are implementation material, not proof that they were run. Replace every bracketed field and mark each check PASS only when its actual output or screenshot is saved. The current project has not been run against a university VM by the author of this bundle.

## Abstract

Smart City Command Centre is a single Ubuntu Server administration project that demonstrates separation of four simulated municipal departments (traffic, safety, water, utilities). Local syslog facilities local0 through local3 route messages into department-specific files. Linux groups and setgid directories restrict department access. An optional LVM logical volume provides an archive mount. Bash scripts generate health reports, create and retain compressed archives, install Cron schedules, and back up and restore project data.

The included dashboard has two run modes. Kali WSL mode is a local rehearsal UI with persistent SQLite incident records and WSL host metrics. Ubuntu live mode runs as a dedicated unprivileged systemd service, reads selected service states, archive capacity, and department log tails, and remains bound to loopback. A private SSH tunnel provides browser access from Kali without exposing the dashboard port. Present it as live only after the corresponding VM deployment and checks have actually succeeded.

The default configuration deliberately simulates department sources locally. It does not enable a remote syslog listener or open network port 514. This keeps the demonstration scoped to one VM and avoids presenting local routing as remote log collection.

## 1. Problem statement

A small city operations team needs department events organized by function, restricted to authorized users, archived consistently, and recoverable after data loss. Manual log sorting, shared writable folders, untracked storage growth, and untested backups make operations difficult to audit and recover.

## 2. Objectives and scope

- Route four facility classes to separate department log files.
- Apply group-based access control and verify cross-department isolation.
- Demonstrate LVM-backed archive storage and controlled capacity growth.
- Produce machine health reports and schedule routine administration jobs.
- Archive old logs with integrity checks and preserve originals.
- Back up project data and restore it to a separate directory.
- Demonstrate safe operational practice: inspection, dry-run behavior, explicit confirmation, and evidence-based reporting.

**In scope:** one approved Ubuntu Server VM; locally generated syslog events; groups and directories; optional dedicated data disk for LVM; backup/restore; Cron.  
**Out of scope:** remote syslog ingestion, high availability, a monitoring dashboard, and production security certification.

## 3. Requirements mapping

| Requirement | Implementation | Verification evidence |
|---|---|---|
| Department log separation | rsyslog local0–local3 rules | Four log files contain their matching test message |
| Access control | traffic/safety/water/utilities groups; mode 2770 directories | `getent group`, `ls -ld`, account-by-folder access matrix |
| Storage management | `smartcity_vg/archives`, ext4 at `/srv/smartcity/archives` | `pvs`, `vgs`, `lvs`, `findmnt`, `df -hP` |
| Archival and retention | timestamped gzip tar archive; 7-day selection; 30-day cleanup | archive listing, `gzip -t`, retained original logs |
| Monitoring and automation | health report and `/etc/cron.d/smartcity` | report output and observed Cron execution |
| Backup and recovery | timestamped compressed backup; restore into empty target | backup listing and inspected restored files |
| Security | group ownership, non-login demo users, preview-first UFW | access check and service/firewall status |

## 4. Architecture and workflow

See [ARCHITECTURE.md](ARCHITECTURE.md) for the editable Mermaid diagram.

1. A demo script sends messages using facilities local0–local3.
2. rsyslog matches each facility and appends to its corresponding file under `/srv/smartcity/logs`.
3. Department groups govern folder access. Directories use mode 2770 so new items inherit the department group.
4. Archive scripts select eligible logs and write compressed bundles to `/srv/smartcity/archives` (on the LVM mount when provisioned).
5. Cron schedules health reporting, archiving, cleanup, and project backup.
6. A restore is performed into a separate empty target and inspected.

## 5. Tools and environment

| Component | Purpose |
|---|---|
| Ubuntu Server VM | Target for system configuration |
| Bash + core utilities | Setup, checks, archiving, reporting, recovery |
| rsyslog + `logger` | Local facility-based event routing |
| Linux groups, ownership, permissions | Department access boundaries |
| LVM2 + ext4 | Flexible archive storage |
| Cron | Scheduled administration tasks |
| tar + gzip | Compressed archives and backups |
| UFW | Optional preview-first host firewall policy |

Record actual environment: `lsb_release -a`, `uname -r`, `hostnamectl`, `ip -brief address`.

## 6. Implementation and configuration

### 6.1 Install

From the project directory on the approved Ubuntu VM:

```bash
sudo ./scripts/install_dependencies.sh
sudo ./scripts/install_project.sh
```

The project scripts and configuration are installed under `/opt/smartcity`; data directories are created beneath `/srv/smartcity`.

### 6.2 LVM archive storage

Inspect disks first:

```bash
sudo /opt/smartcity/scripts/inspect_storage.sh
lsblk -f
```

After identifying an instructor-approved, dedicated empty disk, preview the operation and carefully verify its exact device path:

```bash
sudo /opt/smartcity/scripts/setup_lvm_storage.sh --device /dev/DEVICE
```

Only if the disk is confirmed disposable, apply:

```bash
sudo /opt/smartcity/scripts/setup_lvm_storage.sh --device /dev/DEVICE --apply
sudo pvs; sudo vgs; sudo lvs
findmnt /srv/smartcity/archives
```

The script creates PV `smartcity_vg`, LV `archives`, ext4 filesystem and a UUID-based `/etc/fstab` entry. It uses 80% of free extents initially. **This formats the chosen device and destroys its existing data. Never select the OS disk.** If no dedicated disk is available, record LVM as NOT TESTED and request instructor guidance. Optional growth uses `extend_lvm_storage.sh` after confirming free VG extents.

### 6.3 Department access

```bash
sudo /opt/smartcity/scripts/setup_departments.sh
sudo /opt/smartcity/scripts/create_demo_accounts.sh
getent group traffic safety water utilities
ls -ld /srv/smartcity/logs/*
sudo /opt/smartcity/scripts/verify_department_access.sh
```

The setup creates root-owned directories with each department as group and mode 2770. Demo accounts are non-login accounts. For a real approved account, use `add_department_user.sh USER GROUP`, then start a fresh login session and verify with `id USER`.

### 6.4 Local log routing

`config/rsyslog/30-smartcity.conf` maps `local0 → traffic`, `local1 → safety`, `local2 → water`, `local3 → utilities`. Each action writes to a department log and stops further rule processing for that message. `configure_rsyslog.sh` backs up an existing project target, validates with `rsyslogd -N1`, restarts the service, and restores the previous file if validation/restart fails.

```bash
sudo /opt/smartcity/scripts/configure_rsyslog.sh
sudo systemctl status --no-pager rsyslog
sudo /opt/smartcity/scripts/send_demo_logs.sh
sudo /opt/smartcity/scripts/verify_logs.sh
```

These are locally generated test events; they do not demonstrate network reception.

### 6.5 Health, archives, and automation

```bash
/opt/smartcity/scripts/health_report.sh
sudo /opt/smartcity/scripts/health_report.sh --output /srv/smartcity/reports/health-latest.txt
sudo /opt/smartcity/scripts/archive_logs.sh
```

Review the archive dry-run list before `sudo .../archive_logs.sh --execute`. Eligible files are older than seven days; originals are retained. Validate an actual archive with `tar -tzf FILE` and `gzip -t FILE`. Cleanup is designed for archives older than thirty days and should also be reviewed before destructive execution when run manually.

Install and inspect schedule:

```bash
sudo /opt/smartcity/scripts/install_cron.sh
sudo cat /etc/cron.d/smartcity
sudo systemctl status --no-pager cron
```

Schedule: health report 06:00; log archive 01:00; archive cleanup 01:20; backup 02:00. Jobs run as root and append output to `/srv/smartcity/reports/cron.log`.

### 6.6 Backup and restore

```bash
sudo /opt/smartcity/scripts/backup_project.sh
ls -lh /srv/smartcity/backups
sudo /opt/smartcity/scripts/restore_project.sh \
  --archive /srv/smartcity/backups/ACTUAL_BACKUP.tar.gz \
  --target /tmp/smartcity-restore
```

Use the actual generated filename and a new, empty restore target. Inspect the restored tree and compare expected files with the source.

### 6.7 Firewall

The firewall script prints proposed UFW policy by default. Local log simulation requires no inbound syslog port. Apply a policy only if required by the instructor, after confirming network access and retaining console access. The project does not open port 514.

## 7. Testing and results

Fill [EVIDENCE_CHECKLIST.csv](EVIDENCE_CHECKLIST.csv) with date, result, evidence path, and notes. Keep screenshots or terminal captures in `evidence/`.

| Test | Expected observation | Actual result |
|---|---|---|
| Facility routing | Matching message appears in each of four log files | [PASS / FAIL / NOT TESTED + evidence] |
| Access isolation | Each demo user writes only to its own folder | [PASS / FAIL / NOT TESTED + evidence] |
| LVM mount | LV is mounted at archive path and visible in `df` | [PASS / FAIL / NOT TESTED + evidence] |
| Archive integrity | Archive lists and `gzip -t` succeeds | [PASS / FAIL / NOT TESTED + evidence] |
| Health report | Report includes live VM resource values | [PASS / FAIL / NOT TESTED + evidence] |
| Cron execution | At least one scheduled run produces expected output | [PASS / FAIL / NOT TESTED + evidence] |
| Restore | Restored files are present and readable in separate target | [PASS / FAIL / NOT TESTED + evidence] |
| Service/firewall | Actual state is recorded; any applied policy is verified | [PASS / FAIL / NOT TESTED + evidence] |

**Observed results summary:** [Write only results supported by saved evidence.]  
**Known failures / skipped checks:** [Describe honestly.]  
**VM values:** [CPU, memory, disk, uptime, OS version, LVM size.]

## 8. Security considerations and limitations

- Department data access is controlled by supplementary groups and directory modes; add only authorized users.
- Demo accounts are non-login and intended for access-control checks only.
- The default uses local syslog facilities. It does not enable a remote listener, sender allowlist, TLS, or network syslog rules.
- LVM setup is destructive to the selected disk; inspect before applying and use a dedicated empty device.
- Cron archive cleanup is destructive for archives past the retention age; preserve required records before applying.
- UFW is optional and preview-first; verify SSH connectivity and console access before applying firewall changes.
- Backups on the same VM/storage are not off-host disaster recovery. A production design should copy backups to approved separate storage and test restores.
- This coursework implementation is a demonstration and needs institution-specific review before operational use.

## 9. Challenges and solutions

| Challenge | Mitigation / actual experience |
|---|---|
| No dedicated data disk | Do not initialize the OS disk; seek instructor approval or report LVM as not tested. Actual: [fill] |
| Distinguishing local from remote logging | Explicitly document local simulation and leave port 514 closed. Actual: [fill] |
| Group membership not visible in an existing session | Re-login and verify `id USER`. Actual: [fill] |
| Scheduled jobs need time to execute | Capture schedule and a real execution log; do not treat the schedule alone as proof. Actual: [fill] |

## 10. Team contributions

| Member / ID | Responsibility | Individual contribution | Evidence / viva topic |
|---|---|---|---|
| [Member 1] | Infrastructure | [Fill] | [Fill] |
| [Member 2] | Accounts/access | [Fill] | [Fill] |
| [Member 3] | Storage/logging | [Fill] | [Fill] |
| [Member 4] | Automation/reporting | [Fill] | [Fill] |

All team members should be able to explain the overall flow and the safety implications of disk, firewall, and cleanup operations.

## 11. Conclusion and future enhancements

The solution combines Linux access controls, facility-based log routing, optional LVM archive storage, Bash automation, scheduled jobs, and a verifiable restore path in a compact single-VM project. The final conclusion must be updated to reflect the tests actually completed by the team.

Potential enhancements, subject to instructor approval: remote syslog senders over a private network with authenticated/encrypted transport; off-host backups; storage-threshold alerts; monitoring dashboard; periodic recovery drills.

## References

- Project implementation and configuration in this submission (`scripts/`, `config/`).
- Ubuntu VM manual pages: `man rsyslog.conf`, `man logger`, `man lvm`, `man lvextend`, `man chmod`, `man chown`, `man crontab`, `man tar`, `man systemctl`, `man ufw`.
- Ubuntu release and package documentation installed on the target system: [record the release/version and consulted references].

## Appendix A — Evidence capture commands

```bash
hostnamectl
lsb_release -a
getent group traffic safety water utilities
ls -ld /srv/smartcity/logs/*
sudo /opt/smartcity/scripts/verify_department_access.sh
sudo /opt/smartcity/scripts/verify_logs.sh
sudo pvs; sudo vgs; sudo lvs; findmnt /srv/smartcity/archives; df -hP /srv/smartcity/archives
sudo cat /etc/cron.d/smartcity
ls -lh /srv/smartcity/archives /srv/smartcity/backups /srv/smartcity/reports
```
