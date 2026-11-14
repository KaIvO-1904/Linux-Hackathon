# Smart City Command Centre — Project Report

> Replace bracketed notes with your team's real details and evidence. Do not mark a requirement PASS until you have captured actual output from the Ubuntu VM.

## Cover information

- Course: Linux System Administration (E1ITA307)
- Team name: [team name]
- Members and registration numbers: [names and numbers]
- Assigned problem statement: Smart City Command Centre
- Linux distribution/version: [actual version]
- Date: [date]

## 1. Problem and objectives

Describe the operational need for centralized department logs, controlled access, archival, storage management, monitoring, and recovery.

## 2. Requirements and design

| Requirement | Design choice | Evidence |
|---|---|---|
| Department log separation | Local syslog facilities routed to separate files | [screenshot/output] |
| Department access control | Linux groups and setgid directories | [screenshot/output] |
| Storage management | LVM logical volume mounted at `/srv/smartcity/archives` | [screenshot/output] |
| Log archival and retention | Timestamped gzip tar archives and retention script | [screenshot/output] |
| Health monitoring | Bash report plus Cron schedule | [screenshot/output] |
| Backup and recovery | Compressed project backup restored to a separate directory | [screenshot/output] |
| Secure access | SSH and approved UFW policy | [screenshot/output] |

Include the actual architecture diagram and explain whether sources were remote or locally simulated. This bundle's default is local simulation.

## 3. Team responsibilities

| Member | Assigned role | Contribution and evidence |
|---|---|---|
| [member 1] | Infrastructure | [work performed] |
| [member 2] | Accounts and access | [work performed] |
| [member 3] | Storage and logging | [work performed] |
| [member 4] | Automation and documentation | [work performed] |

## 4. Implementation

Document the actual commands and configuration for:

1. VM and OS setup.
2. LVM physical volume, volume group, logical volume, filesystem, and mount.
3. Groups, demonstration users, directory permissions, and access checks.
4. Rsyslog rules and test messages.
5. Archival, retention, and LVM extension.
6. Health report and Cron jobs.
7. Backup, integrity check, and restoration.
8. SSH/firewall settings, if configured.

## 5. Verification results

| Check | Result (PASS/FAIL/NOT TESTED) | Evidence / notes |
|---|---|---|
| Each department's log file receives its test message | [result] | [evidence] |
| Department users can write only to their own folder | [result] | [evidence] |
| Archive can be listed and passes gzip integrity check | [result] | [evidence] |
| LVM archive filesystem is mounted and visible in `df` | [result] | [evidence] |
| Health report contains actual resource data | [result] | [evidence] |
| Cron job ran and produced output | [result] | [evidence] |
| Backup was restored and contents inspected | [result] | [evidence] |
| Firewall/service configuration checked | [result] | [evidence] |

## 6. Security, limitations, and future work

Explain group access, SSH/firewall policy, and how the archive volume is protected. State clearly that the default solution locally simulates several department sources and does not accept remote syslog. List any skipped tests or features. Future work may add approved remote senders, alerts, or a dashboard.

## 7. Conclusion

Summarize what the team actually implemented and verified.
