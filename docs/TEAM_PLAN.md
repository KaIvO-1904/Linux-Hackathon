# Team Plan

Use this as a starting division of work for a four-person team. Everyone should understand the overall flow and participate in the final integration and viva.

| Member | Role | Main tasks | Evidence to capture |
|---|---|---|---|
| 1 | Linux infrastructure lead | Confirm Ubuntu version, install dependencies, configure hostname/network, SSH, and approved firewall policy | `hostnamectl`, `ip -brief address`, service and UFW status |
| 2 | Accounts and access lead | Create department groups/folders, demo accounts, and verify isolation | `getent group`, `id`, `ls -ld`, access-check output |
| 3 | Storage and logging lead | Prepare LVM archive mount, configure rsyslog routing, generate and inspect archives | `pvs`, `vgs`, `lvs`, `findmnt`, log files, archive contents |
| 4 | Automation and documentation lead | Health report, Cron, backup/restore, integration checklist, report and presentation | Health report, Cron file and run evidence, backup/restore output |

## Eight-hour working schedule

| Time | Milestone |
|---|---|
| 00:00–00:30 | Confirm requirements, assign roles, agree on names and paths |
| 00:30–01:15 | Prepare Ubuntu VM and install approved packages |
| 01:15–02:00 | Set up LVM archive storage, departments, groups, and accounts |
| 02:00–03:15 | Configure and demonstrate department log routing |
| 03:15–04:15 | Create and validate archives; demonstrate LVM growth if time permits |
| 04:15–05:15 | Generate system and storage health reports |
| 05:15–06:00 | Install and inspect Cron schedules |
| 06:00–06:40 | Create a backup and restore it to a separate directory |
| 06:40–07:20 | Integration, access, service, and firewall checks |
| 07:20–08:00 | Capture evidence and rehearse demo/viva |

The storage/LVM work requires a dedicated empty data disk. If the VM does not have one, ask the instructor before changing any disk configuration. Drop optional features before compressing verification or presentation time.
