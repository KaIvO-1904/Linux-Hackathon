const DEPT_CLASS = {"Traffic":"traffic","Public Safety":"safety","Water":"water","Utilities":"utilities"};
const $ = (id) => document.getElementById(id);
let searchTimer;
let toastTimer;
let currentPage = 1;
let totalPages = 1;

function safeText(value) {
  const node = document.createElement('span'); node.textContent = value ?? ''; return node.innerHTML;
}
function showToast(message) {
  const toast = $('toast'); toast.textContent = message; toast.classList.add('visible');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove('visible'), 2800);
}
function formatUptime(hours) {
  if (hours == null) return '—';
  const days = Math.floor(hours / 24), remaining = Math.floor(hours % 24);
  return days ? `${days}d ${remaining}h` : `${remaining}h`;
}
function eventMarkup(event) {
  const cls = DEPT_CLASS[event.department] || 'traffic';
  const severity = event.level.toLowerCase();
  const status = event.status.toLowerCase();
  let action = '';
  if (event.status === 'Open') action = `<button class="row-action" data-id="${event.id}" data-status="Acknowledged">Acknowledge</button>`;
  else if (event.status === 'Acknowledged') action = `<button class="row-action" data-id="${event.id}" data-status="Resolved">Resolve</button>`;
  else action = `<button class="row-action reopen-action" data-id="${event.id}" data-status="Open">Reopen</button>`;
  return `<tr><td class="time-cell">${safeText(event.time)}</td><td><span class="dept-tag ${cls}"><i></i>${safeText(event.department)}</span></td><td class="event-title">${safeText(event.title)}<small>${safeText(event.detail || 'No location or detail added')}</small></td><td><span class="severity ${severity}">${safeText(event.level.toUpperCase())}</span></td><td><span class="record-status ${status}">${safeText(event.status)}</span></td><td>${action}</td></tr>`;
}
async function loadEvents() {
  const params = new URLSearchParams();
  if ($('event-search').value.trim()) params.set('q', $('event-search').value.trim());
  if ($('department-filter').value) params.set('department', $('department-filter').value);
  if ($('severity-filter').value) params.set('level', $('severity-filter').value);
  if ($('status-filter').value) params.set('status', $('status-filter').value);
  params.set('page', String(currentPage)); params.set('limit','12');
  $('last-updated').textContent = 'updating…';
  try {
    const response = await fetch(`/api/events?${params}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Could not load incidents');
    totalPages = data.pages;
    $('event-rows').innerHTML = data.events.length ? data.events.map(eventMarkup).join('') : '<tr class="empty-row"><td colspan="6">No records match these filters. Record an incident to get started.</td></tr>';
    $('event-summary').textContent = `Showing ${data.events.length ? (currentPage-1)*12+1 : 0}–${(currentPage-1)*12+data.events.length} of ${data.total} records`;
    $('page-label').textContent = `${currentPage} / ${totalPages}`;
    $('previous-page').disabled = currentPage <= 1;
    $('next-page').disabled = currentPage >= totalPages;
    $('last-updated').textContent = 'just now';
  } catch (error) { $('last-updated').textContent = 'offline'; showToast(error.message); }
}
async function refreshDashboard() {
  try {
    const response = await fetch('/api/dashboard', {cache:'no-store'});
    if (!response.ok) throw new Error('Dashboard data unavailable');
    const data = await response.json(), host = data.host, summary = data.summary;
    $('env-name').textContent = host.environment;
    $('workspace-mode').textContent = data.mode === 'ubuntu-live' ? 'Ubuntu live host' : 'Local rehearsal';
    $('mode-badge').lastChild.textContent = data.mode === 'ubuntu-live' ? ' UBUNTU LIVE' : ' SIMULATION';
    $('department-metric-label').textContent = data.mode === 'ubuntu-live' ? 'DEPARTMENT LOG SOURCES' : 'DEPARTMENTS IN DEMO';
    $('department-metric-sub').textContent = data.mode === 'ubuntu-live' ? 'local syslog facilities' : 'simulated sources';
    $('department-metric-foot').textContent = data.mode === 'ubuntu-live' ? 'read-only file status' : 'local0 through local3';
    const connectedDepartments = data.mode === 'ubuntu-live' ? data.departments.filter(item => item.status === 'Log available').length : 4;
    $('department-online-count').textContent = connectedDepartments;
    document.querySelectorAll('.status-track i').forEach((bar, index) => bar.classList.toggle('offline', index >= connectedDepartments));
    $('host-inline').textContent = host.environment;
    $('host-name').textContent = host.hostname;
    $('host-os').textContent = host.os;
    $('mode-notice').innerHTML = data.mode === 'ubuntu-live'
      ? `<strong>Ubuntu live mode.</strong> Host metrics, service states, archive mount, and readable department log tails come from ${safeText(host.hostname)}. Incident-register records are stored in this VM's local SQLite database; the separate log panel reads the VM's routed files.`
      : `<strong>Kali WSL rehearsal mode.</strong> Host metrics come from ${safeText(host.environment)}. Department sources are simulated and incident examples are local rehearsal records; the university Ubuntu VM is not connected.`;
    $('live-systems').hidden = !data.runtime;
    if (!data.runtime) {
      $('archive-total').textContent = '—'; $('archive-card-note').textContent = 'Capacity appears here in Ubuntu live mode';
      $('archive-used').textContent = '—'; $('archive-free').textContent = '—'; $('archive-progress').style.width = '0%';
    }
    document.querySelectorAll('#automation .schedule-state').forEach(node => { if (data.runtime) node.textContent = data.runtime.cron_configured ? 'INSTALLED' : 'NOT INSTALLED'; });
    $('health-value').textContent = host.health_score ?? '—';
    $('incident-count').textContent = summary.open_incidents;
    $('active-summary').textContent = `${summary.active_incidents} open or acknowledged`;
    $('event-total').textContent = summary.total_events;
    $('cpu-value').textContent = host.cpu_used_percent == null ? '—' : `${host.cpu_used_percent}%`;
    $('cpu-bar').style.width = `${Math.min(100,host.cpu_used_percent||0)}%`;
    $('cpu-sub').textContent = 'Read-only sample from /proc/stat';
    $('memory-value').textContent = host.memory_used_percent == null ? '—' : `${host.memory_used_percent}%`;
    $('memory-bar').style.width = `${Math.min(100,host.memory_used_percent||0)}%`;
    $('memory-sub').textContent = host.memory_total_gb == null ? 'Unavailable in this environment' : `${host.memory_used_gb} GB used of ${host.memory_total_gb} GB visible to Linux`;
    $('disk-value').textContent = host.disk_used_percent == null ? '—' : `${host.disk_used_percent}%`;
    $('disk-bar').style.width = `${Math.min(100,host.disk_used_percent||0)}%`;
    $('disk-sub').textContent = `${host.disk_used_gb} GB used of ${host.disk_total_gb} GB · Linux root filesystem`;
    $('load-value').textContent = host.load.length ? host.load.join(' / ') : '—';
    $('uptime-value').textContent = formatUptime(host.uptime_hours);
    $('date-now').textContent = new Intl.DateTimeFormat(undefined,{weekday:'short',month:'short',day:'numeric'}).format(new Date());
    data.departments.forEach(department => {
      const row = document.querySelector(`[data-department="${department.name}"]`);
      if (!row) return;
      const count = row.querySelector('.department-stat strong');
      if (count) count.textContent = String(department.open_incidents).padStart(2,'0');
      const label = row.querySelector('.department-stat small');
      if (label) label.textContent = 'Active cases';
      const status = row.querySelector('.department-status');
      if (status) status.innerHTML = `<i></i> ${safeText(department.status)}`;
    });
    if (data.runtime) renderRuntime(data.runtime);
    await loadEvents();
  } catch (error) { showToast('Could not load local app data. Is dashboard/run.sh running?'); }
}
function renderRuntime(runtime) {
  const services = Object.entries(runtime.services);
  $('service-grid').innerHTML = services.length ? services.map(([name,state]) => `<div class="service-chip"><span>${safeText(name)}</span><strong class="service-${safeText(state)}">${safeText(state)}</strong></div>`).join('') : '<p class="live-read-note">systemctl status is unavailable.</p>';
  const storage = runtime.storage;
  $('archive-state').textContent = storage.mounted ? 'Mounted' : 'Not mounted';
  $('archive-capacity').textContent = storage.mounted ? `${storage.used_gb} GB used of ${storage.total_gb} GB (${storage.percent}%)` : storage.path;
  $('archive-total').textContent = storage.mounted ? `${storage.total_gb} GB` : 'Not mounted';
  $('archive-card-note').textContent = storage.mounted ? 'Live VM archive filesystem capacity' : 'Mount the LVM archive filesystem to enable storage reporting';
  $('archive-used').textContent = storage.mounted ? `${storage.used_gb} GB` : '—';
  $('archive-free').textContent = storage.mounted ? `${Math.max(0,storage.total_gb-storage.used_gb).toFixed(2)} GB` : '—';
  $('archive-progress').style.width = `${storage.mounted ? storage.percent : 0}%`;
  $('archive-help').textContent = storage.mounted ? 'Live read-only capacity from the mounted archive filesystem.' : 'Attach the approved separate data disk, then complete the LVM setup from the VM runbook.';
  $('cron-state').textContent = runtime.cron_configured ? 'Configured' : 'Not installed';
  $('log-read-note').textContent = runtime.readable_logs.length ? `Read-only access · ${runtime.readable_logs.length} department log file(s)` : 'No department log files are readable yet. Apply the dashboard access setup on the Ubuntu VM.';
  $('live-log-list').innerHTML = runtime.logs.length ? runtime.logs.map(log => `<article class="live-log-entry"><span class="dept-tag ${DEPT_CLASS[log.department]}"><i></i>${safeText(log.department)}</span><span class="severity ${log.level.toLowerCase()}">${safeText(log.level.toUpperCase())}</span><p>${safeText(log.message)}</p><small>${safeText(log.time)}</small></article>`).join('') : '<div class="live-log-empty">No routed department messages yet. Send the demo messages from the Ubuntu runbook.</div>';
}
async function updateStatus(id, status) {
  try {
    const response = await fetch(`/api/events/${id}`, {method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({status})});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Could not update incident');
    showToast(`Incident ${id} marked ${status.toLowerCase()}.`);
    currentPage = 1; await refreshDashboard();
  } catch (error) { showToast(error.message); }
}
async function saveIncident(event) {
  event.preventDefault();
  const error = $('form-error'); error.textContent = '';
  const form = new FormData(event.currentTarget);
  const payload = Object.fromEntries(form.entries());
  try {
    const response = await fetch('/api/events',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Could not save incident');
    $('incident-dialog').close(); event.currentTarget.reset();
    showToast('Incident saved to the local SQLite register.');
    currentPage = 1; await refreshDashboard();
  } catch (err) { error.textContent = err.message; }
}
document.addEventListener('DOMContentLoaded', () => {
  refreshDashboard();
  setInterval(refreshDashboard, 30000);
  $('refresh-button').addEventListener('click', refreshDashboard);
  $('new-event-button').addEventListener('click', () => $('incident-dialog').showModal());
  $('incident-form').addEventListener('submit', saveIncident);
  document.querySelector('.dialog-close').addEventListener('click', () => $('incident-dialog').close());
  document.querySelector('.cancel-button').addEventListener('click', () => $('incident-dialog').close());
  ['event-search','department-filter','severity-filter','status-filter'].forEach(id => $(id).addEventListener(id === 'event-search' ? 'input' : 'change', () => {
    currentPage = 1; clearTimeout(searchTimer); searchTimer = setTimeout(loadEvents, id === 'event-search' ? 220 : 0);
  }));
  $('previous-page').addEventListener('click', () => { if (currentPage > 1) { currentPage--; loadEvents(); } });
  $('next-page').addEventListener('click', () => { if (currentPage < totalPages) { currentPage++; loadEvents(); } });
  $('export-button').addEventListener('click', () => {
    const params = new URLSearchParams();
    if ($('event-search').value.trim()) params.set('q',$('event-search').value.trim());
    if ($('department-filter').value) params.set('department',$('department-filter').value);
    if ($('severity-filter').value) params.set('level',$('severity-filter').value);
    if ($('status-filter').value) params.set('status',$('status-filter').value);
    window.location.assign(`/api/export.csv?${params}`);
  });
  $('event-rows').addEventListener('click', event => {
    const button = event.target.closest('[data-status]');
    if (button) updateStatus(button.dataset.id, button.dataset.status);
  });
  document.querySelector('.notice-close').addEventListener('click', () => document.querySelector('.notice').remove());
  document.querySelectorAll('.nav-item, [data-nav]').forEach(link => link.addEventListener('click', event => {
    const targetId = link.dataset.nav || link.getAttribute('href')?.slice(1);
    const target = document.getElementById(targetId);
    if (!target) { event.preventDefault(); showToast('This section is represented in the local demo view.'); return; }
    document.querySelectorAll('.nav-item').forEach(item => item.classList.toggle('active',item.getAttribute('href') === `#${targetId}`));
  }));
});
