# Smart City dashboard

A local incident-management application with two run modes: current-host monitoring in Kali WSL and Ubuntu VM live read-only monitoring. It uses Python 3's standard library, SQLite, and static HTML/CSS/JavaScript. There are no pip packages, npm packages, external assets, or preloaded example incidents.

## Start

Open Kali WSL and run:

```bash
cd /mnt/d/Linux-Hackathon
bash dashboard/run.sh
```

Open <http://localhost:8765> in the Windows browser. Stop the server with `Ctrl+C`. To use another port, set `SMARTCITY_PORT=8766 bash dashboard/run.sh`, then open that port in the browser.

After updating the dashboard files, stop any old process with `Ctrl+C`, start it again, and hard-refresh the browser (`Ctrl+F5`). The dashboard does not hot-reload Python changes; an old process can keep serving old API behavior until restarted.

## Features

- Incident register starts empty and is persisted to `~/.local/state/smartcity-dashboard/smartcity.sqlite3` in Kali mode (on the WSL Linux filesystem), and `/var/lib/smartcity-dashboard/smartcity.sqlite3` in Ubuntu service mode. Set `SMARTCITY_DB` to choose another path.
- Create incidents with department, severity, title, and detail/location.
- Acknowledge or resolve open records; reopen or change status using the API if needed.
- Search incidents, filter by department/severity, and export matching records as CSV.
- Auto-refresh dashboard summaries every 30 seconds.
- Read-only host statistics from the Linux environment where the app runs.
- Separate Overview, Departments, Incidents, Infrastructure, and Automation views, with browser back/forward navigation.
- Responsive layout for desktop and mobile widths.

## Kali WSL mode

When started in Kali WSL, the host panel reports actual CPU, memory, root filesystem usage, load, and uptime from Kali. The incident register is empty on first launch and shows only records you enter. This host mode does not claim to have city telemetry or a connection to the university Ubuntu VM. It does not invoke administration scripts, call `logger`, require `sudo`, or change system services/firewall settings.

## Ubuntu VM live mode

`install_project.sh` copies the dashboard to `/opt/smartcity/dashboard`. On the approved Ubuntu VM, run the following after installing dependencies and setting up department folders:

```bash
sudo /opt/smartcity/scripts/setup_dashboard_access.sh
sudo /opt/smartcity/scripts/install_dashboard_service.sh
```

This creates a locked system account and grants it read-only ACL access to the four routed department logs. A systemd sandbox runs the web app as that unprivileged account and binds only to `127.0.0.1:8765`. Live mode reads the VM's CPU, memory, disk, `rsyslog`, `cron`, and `ssh` status, archive mount capacity, Cron file state, and existing lines from the fixed department log paths. It never fills in sample rows or writes system logs. Incident records created through the dashboard are stored separately in `/var/lib/smartcity-dashboard/`.

If a department log file is empty or missing, the dashboard reports that state; it does not create sample events. Any records generated with `scripts/send_demo_logs.sh` are simulated by that optional project helper and should not be presented as real municipal telemetry.

From Kali WSL, reach it through an SSH tunnel (replace the account and reachable VM address):

```bash
ssh -N -L 8766:127.0.0.1:8765 <username>@<ubuntu-vm-address>
```

Then browse to <http://localhost:8766>. The SSH tunnel keeps the dashboard port private; do not open port 8765 in UFW or bind the web app to a public interface. If the VM address is not reachable from your current network, use the VM's approved university access method or use Kali demo mode.

The server binds to `127.0.0.1` only in both modes. Keep it local. There are no preloaded example records. Any user on the same Linux host can open the local dashboard and edit its incident register. On the VM, reach it only from trusted local accounts or authenticated SSH tunnels. Database files are created with owner-only permissions. Treat the SQLite file as project data; back it up or export CSV if the incident history should be retained.

## API

- `GET /api/dashboard` — host snapshot, department incident counts, summary, recent events.
- `GET /api/events?q=&department=&level=&status=&page=&limit=` — filter and paginate the incident register.
- `POST /api/events` — create a validated incident JSON record.
- `PATCH /api/events/{id}` — set `status` to `Open`, `Acknowledged`, or `Resolved`.
- `GET /api/export.csv?q=&department=&level=&status=` — download all matching incident records as CSV.
