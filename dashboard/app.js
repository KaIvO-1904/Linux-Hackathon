const DEPT_CLASS = {"Traffic":"traffic","Public Safety":"safety","Water":"water","Utilities":"utilities"};
const $ = (id) => document.getElementById(id);
let searchTimer;
let toastTimer;
let currentPage = 1;
let totalPages = 1;
let currentView = 'overview';
let hasLiveRuntime = false;
let noticeDismissed = false;

const PAGE_CONFIG = {
  overview: {hash:'#overview', label:'Overview', title:'Operations, in <span class="heading-period">focus.</span>', subtitle:'Live host signals and the incidents you record.'},
  departments: {hash:'#departments', label:'Departments', title:'Department <span class="heading-period">sources.</span>', subtitle:'Facility mapping, source availability, and active incident counts.'},
  events: {hash:'#activity', label:'Incidents', title:'Incident <span class="heading-period">register.</span>', subtitle:'Record, search, update, and export operator-entered incidents.'},
  infrastructure: {hash:'#infrastructure', label:'Infrastructure', title:'Host <span class="heading-period">health.</span>', subtitle:'Current host resources and read-only Ubuntu VM status.'},
  automation: {hash:'#automation', label:'Automation', title:'Scheduled <span class="heading-period">work.</span>', subtitle:'Project Cron jobs and archive retention configuration.'}
};

function viewFromHash(hash) {
  return Object.keys(PAGE_CONFIG).find(page => PAGE_CONFIG[page].hash === hash) || 'overview';
}
function showPage(page, {updateHistory = true} = {}) {
  if (!PAGE_CONFIG[page]) page = 'overview';
  currentView = page;
  document.body.dataset.page = page;
  const config = PAGE_CONFIG[page];
  $('page-title').innerHTML = config.title;
  $('page-subtitle').textContent = config.subtitle;
  $('breadcrumb-title').textContent = config.label;

  $('notice').hidden = page !== 'overview' || noticeDismissed;
  $('metric-grid').hidden = page !== 'overview';
  $('content-grid').hidden = !['overview','departments','infrastructure'].includes(page);
  document.querySelector('.departments-panel').hidden = !['overview','departments'].includes(page);
  document.querySelector('.health-panel').hidden = !['overview','infrastructure'].includes(page);
  $('content-grid').classList.toggle('single-panel', ['departments','infrastructure'].includes(page));
  $('activity').hidden = page !== 'events';
  $('live-systems').hidden = page !== 'infrastructure' || !hasLiveRuntime;
  document.querySelector('.bottom-grid').hidden = !['infrastructure','automation'].includes(page);
  $('automation-panel').hidden = page !== 'automation';
  $('storage-panel').hidden = page !== 'infrastructure';

  document.querySelectorAll('.nav-item[data-page]').forEach(link => {
    const active = link.dataset.page === page;
    link.classList.toggle('active', active);
    if (active) link.setAttribute('aria-current','page');
    else link.removeAttribute('aria-current');
  });
  if (updateHistory && location.hash !== config.hash) history.pushState({page}, '', config.hash);
}

function applyTheme(theme) {
  const selected = theme === 'dark' ? 'dark' : 'light';
  document.documentElement.dataset.theme = selected;
  const label = selected === 'dark' ? 'Light mode' : 'Dark mode';
  $('theme-label').textContent = label;
  document.querySelector('.theme-icon').textContent = selected === 'dark' ? '☀' : '◐';
  $('theme-toggle').setAttribute('aria-label', `Switch to ${selected === 'dark' ? 'light' : 'dark'} mode`);
  $('theme-toggle').title = label;
  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (themeColor) themeColor.content = selected === 'dark' ? '#000000' : '#fffafd';
  try { localStorage.setItem('smartcity-theme', selected); } catch (_) { /* Theme still works for this page view. */ }
}

function safeText(value) {
  const node = document.createElement('span'); node.textContent = value ?? ''; return node.innerHTML;
}
function showToast(message) {
  const toast = $('toast'); toast.textContent = message; toast.classList.add('visible');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove('visible'), 6000);
}
async function readApiResponse(response) {
  let data = null;
  try { data = await response.json(); } catch (_) { /* Report the HTTP status for non-JSON server errors. */ }
  if (!response.ok) {
    let message = data?.error || `Request failed (${response.status} ${response.statusText}).`;
    if (response.status === 403) message += ' Restart the dashboard and reload the page to use the updated local request check.';
    if (response.status === 501) message += ' Restart the dashboard to load the status-update handler.';
    throw new Error(message);
  }
  if (!data) throw new Error('The dashboard returned an unreadable response. Restart it and reload the page.');
  return data;
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
    const data = await readApiResponse(response);
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
    const data = await readApiResponse(response), host = data.host, summary = data.summary;
    $('env-name').textContent = host.environment;
    const liveUbuntu = data.mode === 'ubuntu-live';
    $('workspace-mode').textContent = liveUbuntu ? 'Ubuntu live host' : `${host.environment} host`;
    $('mode-badge').lastChild.textContent = liveUbuntu ? ' UBUNTU LIVE' : ' LOCAL HOST';
    $('department-metric-sub').textContent = liveUbuntu ? 'read-only file access' : 'No feed connected';
    $('department-metric-foot').textContent = liveUbuntu ? 'Configured local0–local3 logs' : 'No live department feeds';
    const connectedDepartments = liveUbuntu ? data.departments.filter(item => item.status === 'Log readable').length : 0;
    $('department-online-count').textContent = connectedDepartments;
    document.querySelectorAll('.status-track i').forEach((bar, index) => bar.classList.toggle('offline', index >= connectedDepartments));
    $('host-name').textContent = host.hostname;
    $('host-os').textContent = host.os;
    $('mode-notice').innerHTML = liveUbuntu
      ? `<strong>Ubuntu live mode.</strong> Resource readings and service, mount, Cron, and log status are read from ${safeText(host.hostname)}. The incident register starts empty and contains only records entered by an operator.`
      : `<strong>${safeText(host.environment)} local host mode.</strong> Resource readings below come from this Linux environment. No city log source is connected here. The incident register starts empty and contains only records you enter.`;
    $('incident-storage-note').textContent = liveUbuntu ? 'This saves a record on the Ubuntu VM.' : `This saves a record on this ${host.environment} host.`;
    $('department-feed-summary').textContent = liveUbuntu
      ? `${connectedDepartments} of 4 configured department log files readable.`
      : `No department log feeds are connected in ${host.environment}.`;
    hasLiveRuntime = Boolean(data.runtime);
    showPage(currentView, {updateHistory:false});
    if (!data.runtime) {
      $('archive-total').textContent = '—'; $('archive-card-note').textContent = 'Capacity appears here in Ubuntu live mode';
      $('archive-used').textContent = '—'; $('archive-free').textContent = '—'; $('archive-progress').style.width = '0%';
    }
    document.querySelectorAll('#automation .schedule-state').forEach(node => { if (data.runtime) node.textContent = data.runtime.cron_configured ? 'INSTALLED' : 'NOT INSTALLED'; });
    if (data.runtime) {
      $('cron-summary').textContent = data.runtime.cron_configured
        ? 'The project Cron file is present on this Ubuntu host; check Cron service status above.'
        : 'The project Cron file is not installed on this Ubuntu host.';
    }
    $('incident-count').textContent = summary.open_incidents;
    $('active-summary').textContent = `${summary.active_incidents} open or acknowledged`;
    $('event-total').textContent = summary.total_events;
    $('cpu-kpi').textContent = host.cpu_used_percent == null ? '—' : `${host.cpu_used_percent}%`;
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
      if (status) {
        status.classList.toggle('source-readable', department.status === 'Log readable');
        status.innerHTML = `<i></i> ${safeText(department.status)}`;
      }
    });
    if (data.runtime) renderRuntime(data.runtime);
    await loadEvents();
  } catch (error) { showToast(`Could not load dashboard data: ${error.message}`); }
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
async function updateStatus(id, status, button) {
  if (button) { button.disabled = true; button.setAttribute('aria-busy', 'true'); }
  try {
    const response = await fetch(`/api/events/${id}`, {method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({status})});
    await readApiResponse(response);
    showToast(`Incident ${id} marked ${status.toLowerCase()}.`);
    currentPage = 1; await refreshDashboard();
  } catch (error) { showToast(`Could not update incident: ${error.message}`); }
  finally { if (button?.isConnected) { button.disabled = false; button.removeAttribute('aria-busy'); } }
}
async function saveIncident(event) {
  event.preventDefault();
  const error = $('form-error'); error.textContent = '';
  const form = new FormData(event.currentTarget);
  const payload = Object.fromEntries(form.entries());
  try {
    const response = await fetch('/api/events',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
    await readApiResponse(response);
    $('incident-dialog').close(); event.currentTarget.reset();
    showToast('Incident saved to this host’s SQLite register.');
    currentPage = 1; await refreshDashboard();
  } catch (err) { error.textContent = err.message; }
}
document.addEventListener('DOMContentLoaded', () => {
  let savedTheme = 'light';
  try { savedTheme = localStorage.getItem('smartcity-theme') || 'light'; } catch (_) { /* Use the light default when storage is unavailable. */ }
  applyTheme(savedTheme);
  $('theme-toggle').addEventListener('click', () => applyTheme(document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'));
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
    const button = event.target.closest('button[data-status]');
    if (button && !button.disabled) updateStatus(button.dataset.id, button.dataset.status, button);
  });
  document.querySelector('.notice-close').addEventListener('click', () => {
    noticeDismissed = true;
    $('notice').hidden = true;
  });
  showPage(viewFromHash(location.hash), {updateHistory:false});
  document.querySelectorAll('[data-page]').forEach(link => link.addEventListener('click', event => {
    event.preventDefault();
    showPage(link.dataset.page);
    window.scrollTo({top:0,behavior:'smooth'});
  }));
  window.addEventListener('popstate', () => showPage(viewFromHash(location.hash), {updateHistory:false}));
});
