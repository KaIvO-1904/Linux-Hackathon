#!/usr/bin/env python3
"""Local-only Smart City dashboard API for Kali WSL and Ubuntu live monitoring."""

from __future__ import annotations

import csv
from contextlib import contextmanager
import io
import json
import os
import platform
import re
import shutil
import socket
import sqlite3
import subprocess
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
DB_PATH = Path(os.environ.get("SMARTCITY_DB", Path.home() / ".local" / "state" / "smartcity-dashboard" / "smartcity.sqlite3"))
HOST = "127.0.0.1"
try:
    PORT = int(os.environ.get("SMARTCITY_PORT", "8765"))
except ValueError as error:
    raise SystemExit("SMARTCITY_PORT must be an integer from 1 to 65535.") from error
if not 1 <= PORT <= 65535:
    raise SystemExit("SMARTCITY_PORT must be an integer from 1 to 65535.")
MODE = os.environ.get("SMARTCITY_MODE", "demo").lower()
DEPARTMENTS = ["Traffic", "Public Safety", "Water", "Utilities"]
MAX_INCIDENTS = 10_000
MAX_EXPORT_ROWS = 5_000
def connect_db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=5)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA busy_timeout=5000")
    return db


@contextmanager
def database():
    db = connect_db()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def initialize_db() -> None:
    with database() as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("""CREATE TABLE IF NOT EXISTS incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            department TEXT NOT NULL CHECK(department IN ('Traffic','Public Safety','Water','Utilities')),
            level TEXT NOT NULL CHECK(level IN ('Info','Warning','Critical')),
            title TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'Open' CHECK(status IN ('Open','Acknowledged','Resolved')),
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )""")
        db.execute("CREATE INDEX IF NOT EXISTS incidents_created_idx ON incidents(created_at DESC)")
def row_to_event(row: sqlite3.Row) -> dict:
    value = dict(row)
    created = datetime.fromisoformat(value["created_at"])
    value["time"] = created.strftime("%H:%M:%S")
    value["source"] = f"local{DEPARTMENTS.index(value['department'])}"
    return value


def read_host() -> dict:
    memory = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, value = line.split(":", 1)
            memory[key] = int(value.strip().split()[0]) * 1024
    except (OSError, ValueError):
        pass
    total = memory.get("MemTotal", 0)
    available = memory.get("MemAvailable", 0)
    disk = shutil.disk_usage("/")
    try:
        uptime_seconds = float(Path("/proc/uptime").read_text().split()[0])
    except (OSError, ValueError, IndexError):
        uptime_seconds = 0
    try:
        loads = [round(float(item), 2) for item in Path("/proc/loadavg").read_text().split()[:3]]
    except (OSError, ValueError):
        loads = []
    release = {}
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                release[key] = value.strip().strip('"')
    except OSError:
        pass
    in_wsl = "microsoft" in platform.release().lower() or "WSL_DISTRO_NAME" in os.environ
    mem_pct = round((total - available) * 100 / total, 1) if total else None
    disk_pct = round(disk.used * 100 / disk.total, 1) if disk.total else None
    cpu_pct = None
    try:
        def cpu_ticks():
            values = [int(value) for value in Path("/proc/stat").read_text().splitlines()[0].split()[1:9]]
            return sum(values), values[3] + values[4]
        total_a, idle_a = cpu_ticks()
        time.sleep(0.12)
        total_b, idle_b = cpu_ticks()
        cpu_pct = round(100 * ((total_b - total_a) - (idle_b - idle_a)) / (total_b - total_a), 1) if total_b > total_a else None
    except (OSError, ValueError, IndexError, ZeroDivisionError):
        pass
    return {
        "hostname": socket.gethostname(), "os": release.get("PRETTY_NAME", platform.system()),
        "environment": "Kali on WSL" if in_wsl and "kali" in release.get("ID", "").lower() else ("WSL Linux" if in_wsl else ("Ubuntu Server" if release.get("ID") == "ubuntu" else "Local Linux")),
        "memory_used_percent": mem_pct, "memory_used_gb": round((total - available) / 1024**3, 1) if total else None,
        "memory_total_gb": round(total / 1024**3, 1) if total else None,
        "disk_used_percent": disk_pct, "disk_used_gb": round(disk.used / 1024**3, 1),
        "disk_total_gb": round(disk.total / 1024**3, 1), "uptime_hours": round(uptime_seconds / 3600, 1),
        "cpu_used_percent": cpu_pct, "load": loads, "sampled_at": datetime.now(timezone.utc).isoformat(),
    }


def read_ubuntu_runtime() -> dict:
    """Read allowlisted service states, archive mount, and routed log tails."""
    service_states = {}
    if shutil.which("systemctl"):
        for service in ("rsyslog", "cron", "ssh"):
            try:
                result = subprocess.run(["systemctl", "is-active", service], capture_output=True, text=True, timeout=3, check=False)
                service_states[service] = result.stdout.strip() if result.returncode in (0, 3, 4) else "unknown"
            except (OSError, subprocess.TimeoutExpired):
                service_states[service] = "unknown"
    mount_path = Path("/srv/smartcity/archives")
    mounted = os.path.ismount(mount_path)
    storage = {"mounted": mounted, "path": str(mount_path), "used_gb": None, "total_gb": None, "percent": None}
    if mounted:
        usage = shutil.disk_usage(mount_path)
        storage.update({"used_gb": round(usage.used / 1024**3, 2), "total_gb": round(usage.total / 1024**3, 2),
                        "percent": round(usage.used * 100 / usage.total, 1) if usage.total else 0})
    logs = []
    readable_logs = []
    for i, (folder, department) in enumerate((("traffic", "Traffic"), ("safety", "Public Safety"), ("water", "Water"), ("utilities", "Utilities"))):
        path = Path("/srv/smartcity/logs") / folder / f"{folder}.log"
        try:
            with path.open("rb") as handle:
                readable_logs.append(department)
                handle.seek(0, os.SEEK_END)
                size = handle.tell()
                handle.seek(max(0, size - 48_000))
                lines = handle.read().decode("utf-8", errors="replace").splitlines()[-12:]
            for line in lines:
                severity = "Critical" if re.search(r"\b(err|error|crit|alert|emerg)\b", line, re.I) else ("Warning" if re.search(r"\b(warn|warning)\b", line, re.I) else "Info")
                logs.append({"department": department, "source": f"local{i}", "level": severity,
                             "time": line[:19], "message": line[-500:]})
        except OSError:
            continue
    logs.sort(key=lambda item: item["time"], reverse=True)
    return {"services": service_states, "storage": storage, "logs": logs[:30],
            "readable_logs": readable_logs, "cron_configured": Path("/etc/cron.d/smartcity").is_file()}


def event_filters(params: dict) -> tuple[str, list[object]]:
    where = " WHERE 1=1"
    values: list[object] = []
    for field, column in (("department", "department"), ("level", "level"), ("status", "status")):
        value = params.get(field, [""])[0]
        if value:
            where += f" AND {column} = ?"
            values.append(value)
    query = params.get("q", [""])[0].strip()[:120]
    if query:
        where += " AND (title LIKE ? OR detail LIKE ? OR department LIKE ?)"
        values.extend([f"%{query}%"] * 3)
    return where, values


def event_query(params: dict, limit: int | None = 200, offset: int = 0) -> list[dict]:
    where, values = event_filters(params)
    sql = "SELECT * FROM incidents" + where + " ORDER BY id DESC"
    if limit is not None:
        sql += " LIMIT ?"
        values.append(limit)
        if offset:
            sql += " OFFSET ?"
            values.append(offset)
    with database() as db:
        return [row_to_event(row) for row in db.execute(sql, values).fetchall()]


def event_count(params: dict) -> int:
    where, values = event_filters(params)
    with database() as db:
        return db.execute("SELECT COUNT(*) FROM incidents" + where, values).fetchone()[0]


class Handler(BaseHTTPRequestHandler):
    server_version = "SmartCityLocal/2.0"

    def send_json(self, data: dict | list, status: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def read_payload(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length < 0 or length > 8192:
            raise ValueError("Request body is too large.")
        result = json.loads(self.rfile.read(length) or b"{}")
        if not isinstance(result, dict):
            raise ValueError("Expected a JSON object.")
        return result

    def authorize_local_request(self) -> bool:
        origin = self.headers.get("Origin")
        if origin is None:
            return True
        try:
            parsed = urlparse(origin)
        except ValueError:
            return False
        request_host = self.headers.get("Host", "").lower()
        return (
            parsed.scheme == "http"
            and parsed.hostname in ("localhost", "127.0.0.1", "::1")
            and parsed.netloc.lower() == request_host
            and parsed.path in ("", "/")
            and not parsed.params and not parsed.query and not parsed.fragment
            and parsed.username is None and parsed.password is None
        )

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        params = parse_qs(urlparse(self.path).query)
        if path == "/api/dashboard":
            with database() as db:
                total = db.execute("SELECT COUNT(*) FROM incidents").fetchone()[0]
                open_count = db.execute("SELECT COUNT(*) FROM incidents WHERE status='Open'").fetchone()[0]
                active_count = db.execute("SELECT COUNT(*) FROM incidents WHERE status!='Resolved'").fetchone()[0]
                groups = db.execute("SELECT department,COUNT(*) AS count FROM incidents WHERE status!='Resolved' GROUP BY department").fetchall()
                all_events = [row_to_event(r) for r in db.execute("SELECT * FROM incidents ORDER BY id DESC LIMIT 7")]
            runtime = read_ubuntu_runtime() if MODE == "ubuntu" else None
            depts = [{"name": name, "open_incidents": next((r["count"] for r in groups if r["department"] == name), 0),
                      "facility": f"local{i}", "status": "Log readable" if runtime and name in runtime["readable_logs"] else ("Log unavailable" if runtime else "No live source")}
                     for i, name in enumerate(DEPARTMENTS)]
            self.send_json({"host": read_host(), "runtime": runtime,
                            "departments": depts, "events": all_events,
                            "summary": {"total_events": total, "open_incidents": open_count, "active_incidents": active_count},
                            "mode": "ubuntu-live" if MODE == "ubuntu" else "local-host"})
            return
        if path == "/api/events":
            try:
                page = max(1, int(params.get("page", ["1"])[0]))
                page_size = min(100, max(1, int(params.get("limit", ["12"])[0])))
            except ValueError:
                self.send_json({"error": "page and limit must be integers."}, 400)
                return
            total = event_count(params)
            pages = max(1, (total + page_size - 1) // page_size)
            page = min(page, pages)
            self.send_json({"events": event_query(params, limit=page_size, offset=(page - 1) * page_size),
                            "total": total, "page": page, "pages": pages})
            return
        if path == "/api/export.csv":
            total = event_count(params)
            rows = event_query(params, limit=MAX_EXPORT_ROWS)
            stream = io.StringIO(newline="")
            writer = csv.DictWriter(stream, fieldnames=["id", "created_at", "department", "level", "title", "detail", "status", "source"])
            writer.writeheader()
            writer.writerows({key: csv_safe(event.get(key, "")) for key in writer.fieldnames} for event in rows)
            body = stream.getvalue().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/csv; charset=utf-8")
            self.send_header("Content-Disposition", 'attachment; filename="smartcity-events.csv"')
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            if total > MAX_EXPORT_ROWS:
                self.send_header("X-Export-Truncated", "true")
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/" or path in ("/index.html", "/styles.css", "/app.js"):
            target = ROOT / ("index.html" if path == "/" else path.lstrip("/"))
            if not target.is_file():
                self.send_error(404)
                return
            body = target.read_bytes()
            content_type = {".html": "text/html", ".css": "text/css", ".js": "application/javascript"}[target.suffix]
            self.send_response(200)
            self.send_header("Content-Type", f"{content_type}; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self) -> None:
        if not self.authorize_local_request():
            self.send_error(403)
            return
        path = urlparse(self.path).path
        if path != "/api/events":
            self.send_error(404)
            return
        try:
            data = self.read_payload()
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json({"error": str(error)}, 400)
            return
        department, level = data.get("department"), data.get("level")
        title = str(data.get("title", "")).strip()
        detail = str(data.get("detail", "")).strip()
        if department not in DEPARTMENTS or level not in ("Info", "Warning", "Critical") or not title or len(title) > 140 or len(detail) > 240:
            self.send_json({"error": "Choose a department and severity, enter a title (1–140 characters), and keep details under 240 characters."}, 400)
            return
        now = datetime.now().astimezone().isoformat(timespec="seconds")
        with database() as db:
            db.execute("BEGIN IMMEDIATE")
            count = db.execute("SELECT COUNT(*) FROM incidents").fetchone()[0]
            if count >= MAX_INCIDENTS:
                self.send_json({"error": f"Incident storage is full ({MAX_INCIDENTS} records). Export or remove old records before adding more."}, 409)
                return
            cursor = db.execute("INSERT INTO incidents(department,level,title,detail,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?)",
                                (department, level, title, detail, "Open", now, now))
            row = db.execute("SELECT * FROM incidents WHERE id=?", (cursor.lastrowid,)).fetchone()
        self.send_json({"event": row_to_event(row)}, 201)

    def do_PATCH(self) -> None:
        if not self.authorize_local_request():
            self.send_error(403)
            return
        path = urlparse(self.path).path
        pieces = path.strip("/").split("/")
        if len(pieces) != 3 or pieces[:2] != ["api", "events"] or not pieces[2].isdigit():
            self.send_error(404)
            return
        try:
            data = self.read_payload()
        except (ValueError, json.JSONDecodeError) as error:
            self.send_json({"error": str(error)}, 400)
            return
        status = data.get("status")
        if status not in ("Open", "Acknowledged", "Resolved"):
            self.send_json({"error": "Status must be Open, Acknowledged, or Resolved."}, 400)
            return
        now = datetime.now().astimezone().isoformat(timespec="seconds")
        with database() as db:
            changed = db.execute("UPDATE incidents SET status=?,updated_at=? WHERE id=?", (status, now, int(pieces[2]))).rowcount
            row = db.execute("SELECT * FROM incidents WHERE id=?", (int(pieces[2]),)).fetchone() if changed else None
        if not row:
            self.send_json({"error": "Incident not found."}, 404)
            return
        self.send_json({"event": row_to_event(row)})

    def log_message(self, fmt: str, *args) -> None:
        print(f"[{self.log_date_time_string()}] {fmt % args}")


def csv_safe(value):
    if isinstance(value, str) and value.lstrip(" \t\r\n").startswith(("=", "+", "-", "@")):
        return "'" + value
    return value


if __name__ == "__main__":
    if MODE not in ("demo", "ubuntu"):
        raise SystemExit("SMARTCITY_MODE must be 'demo' or 'ubuntu'.")
    if MODE == "ubuntu":
        release = Path("/etc/os-release").read_text() if Path("/etc/os-release").exists() else ""
        if not re.search(r"^ID=\"?ubuntu\"?$", release, re.M):
            raise SystemExit("Ubuntu live mode is allowed only on an Ubuntu host. Use SMARTCITY_MODE=demo on Kali WSL.")
        if not Path("/opt/smartcity/config/rsyslog/30-smartcity.conf").is_file():
            raise SystemExit("Ubuntu project files are missing from /opt/smartcity. Install the project bundle first.")
    os.umask(0o077)
    initialize_db()
    if DB_PATH.is_file():
        DB_PATH.chmod(0o600)
    print(f"Smart City {MODE} dashboard: http://localhost:{PORT}")
    print(f"Persistent local SQLite data: {DB_PATH}")
    print("Host metrics are read-only; incident records are stored locally.")
    print("Bound to 127.0.0.1 only. Press Ctrl+C to stop.")
    try:
        ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nDashboard stopped.")
