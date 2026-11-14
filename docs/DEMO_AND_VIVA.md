# Demonstration and Viva Guide

## Suggested live demo (5–7 minutes)

1. State the scenario and show the architecture diagram.
2. Show the department groups and restricted folders with `getent group` and `ls -ld /srv/smartcity/logs/*`.
3. Run `sudo /opt/smartcity/scripts/verify_department_access.sh` and explain the allowed/denied checks.
4. Run `sudo /opt/smartcity/scripts/send_demo_logs.sh`, then `sudo /opt/smartcity/scripts/verify_logs.sh`. Explain that these are locally simulated department sources.
5. Show the archive LVM with `sudo pvs`, `sudo vgs`, `sudo lvs`, `findmnt /srv/smartcity/archives`, and `df -hP /srv/smartcity/archives`.
6. Show the health report and `/etc/cron.d/smartcity`; point to evidence of an actual Cron run.
7. Show a timestamped archive and its integrity check, then restore a backup into a separate directory and inspect it.
8. Close with the actual PASS/FAIL/NOT TESTED results and describe each person's contribution.

## Questions to rehearse

**Why use facilities `local0` to `local3`?**  
They provide separate syslog routing keys for the four simulated departments.

**What does the setgid bit on a department directory do?**  
New files and subdirectories inherit the directory's group, which helps keep department ownership consistent.

**Why put archives on an LVM logical volume?**  
It demonstrates flexible storage allocation and allows the logical volume/filesystem to grow when free extents are available.

**How do you know an archive or backup is usable?**  
Check its compressed-stream integrity, list its members, and perform a restore into a separate empty directory.

**How does Cron run the tasks?**  
The `/etc/cron.d/smartcity` entries specify time, run-as user, and command; output is appended to the project Cron log.

**Are department logs coming from separate networked servers?**  
In the default one-VM demo they are locally generated messages using separate facilities. Do not describe this as remote collection. Remote reception requires a configured listener, approved network sources, and a matching firewall rule.

**What would you improve next?**  
With instructor approval, add remote syslog senders on a private network and alerting for storage thresholds, while retaining the same access controls and verification.
