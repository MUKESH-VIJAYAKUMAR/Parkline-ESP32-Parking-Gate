const PAGE_SIZE = 25;
const state = { view: 'overview', userPage: 1, userQuery: '', eventPage: 1, eventQuery: '', eventDirection: '' };
const $ = (selector) => document.querySelector(selector);
const byId = (id) => document.getElementById(id);

function make(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined && text !== null) node.textContent = text;
  return node;
}

function formatDate(value, options = { day: '2-digit', month: 'short', year: 'numeric' }) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('en-IN', { ...options, timeZone: 'Asia/Kolkata' }).format(date);
}

function timeParts(value) {
  if (!value) return ['—', 'Waiting for vehicle passage'];
  return [
    formatDate(value, { hour: '2-digit', minute: '2-digit', hour12: true }),
    formatDate(value, { day: '2-digit', month: 'short', year: 'numeric' }),
  ];
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, { headers: { Accept: 'application/json', ...(options.headers || {}) }, ...options });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || 'Unable to load this information.');
  return data;
}

function setConnection(status, label) {
  const pill = byId('connection-pill');
  pill.classList.remove('is-connected', 'is-warning', 'is-error');
  pill.classList.add(status);
  byId('connection-label').textContent = label;
}

function showSetupBanner(kind, message) {
  const banner = byId('setup-banner');
  banner.classList.remove('is-hidden');
  if (kind === 'error') {
    byId('banner-title').textContent = 'Supabase connection needs attention';
    byId('banner-message').textContent = message || 'Check the Supabase URL, server-side key, table names, and database setup.';
    setConnection('is-error', 'Connection issue');
  } else {
    byId('banner-title').textContent = 'Connect your parking database';
    byId('banner-message').textContent = 'Add the Supabase secret key to your local .env file, then restart the dashboard. No sample data is shown.';
    setConnection('is-warning', 'Setup required');
  }
}

function hideSetupBanner() {
  byId('setup-banner').classList.add('is-hidden');
  setConnection('is-connected', 'Supabase connected');
}

function setEmpty(id, visible) {
  byId(id).classList.toggle('is-hidden', !visible);
}

function setCellText(cell, text, className = '') {
  const span = make('span', className, text || '—');
  cell.append(span);
}

function personCell(name, plate) {
  const wrap = make('div', 'person-cell');
  const avatar = make('span', 'person-avatar', (name || 'U').trim().slice(0, 2));
  const meta = make('span', 'person-meta');
  meta.append(make('strong', '', name || 'Unregistered card'));
  meta.append(make('small', '', name ? 'Registered driver' : 'No linked parking user'));
  wrap.append(avatar, meta);
  return wrap;
}

function directionChip(direction) {
  const value = (direction || '').toUpperCase();
  const chip = make('span', `direction-chip ${value === 'EXIT' ? 'direction-exit' : 'direction-entry'}`, value === 'EXIT' ? 'Exit' : 'Entry');
  return chip;
}

function statusChip(value) {
  const granted = (value || '').toUpperCase() === 'GRANTED';
  return make('span', `result-chip ${granted ? 'result-granted' : 'result-denied'}`, granted ? 'Granted' : 'Denied');
}

function timestampCell(value) {
  const [primary, secondary] = timeParts(value);
  const cell = make('td');
  cell.append(make('span', 'time-primary', primary), make('span', 'time-secondary', secondary));
  return cell;
}

function makeRecentRow(event) {
  const row = make('tr');
  const user = event.parking_user || {};
  const name = user.full_name || event.user_name;
  const vehicle = user.vehicle_plate || event.vehicle_plate;
  const userCell = make('td'); userCell.append(personCell(name, vehicle));
  const plate = make('td'); setCellText(plate, vehicle || '—', 'plate-text');
  const uid = make('td'); setCellText(uid, event.card_uid, 'uid-chip');
  const direction = make('td'); direction.append(directionChip(event.direction));
  row.append(userCell, plate, uid, direction, timestampCell(event.card_tapped_at), timestampCell(event.vehicle_passed_at));
  return row;
}

function renderRecent(events = []) {
  const body = byId('recent-events-body');
  body.replaceChildren(...events.map(makeRecentRow));
  setEmpty('recent-empty', events.length === 0);
}

function renderDashboard(data) {
  const stats = data.stats || {};
  const entries = Number(stats.entries_today || 0);
  const exits = Number(stats.exits_today || 0);
  const total = entries + exits;
  byId('stat-users').textContent = Number(stats.registered_users || 0).toLocaleString('en-IN');
  byId('stat-inside').textContent = Number(stats.vehicles_inside || 0).toLocaleString('en-IN');
  byId('stat-entries').textContent = entries.toLocaleString('en-IN');
  byId('stat-exits').textContent = exits.toLocaleString('en-IN');
  byId('nav-user-count').textContent = Number(stats.registered_users || 0).toLocaleString('en-IN');
  byId('movement-entries').textContent = entries.toLocaleString('en-IN');
  byId('movement-exits').textContent = exits.toLocaleString('en-IN');
  byId('entry-bar').style.width = total ? `${Math.max(3, entries / total * 100)}%` : '0%';
  byId('exit-bar').style.width = total ? `${Math.max(3, exits / total * 100)}%` : '0%';
  renderRecent(data.recent_events || []);
}

async function loadDashboard() {
  try {
    const data = await requestJson('/api/dashboard');
    if (!data.configured) {
      showSetupBanner('setup');
      byId('stat-users').textContent = '—';
      byId('stat-inside').textContent = '—';
      byId('stat-entries').textContent = '—';
      byId('stat-exits').textContent = '—';
      byId('nav-user-count').textContent = '—';
      renderRecent([]);
      return;
    }
    renderDashboard(data);
    if (data.error) showSetupBanner('error'); else hideSetupBanner();
  } catch (error) {
    showSetupBanner('error');
    renderRecent([]);
  }
}

function renderPagination(prefix, page, total, limit, prevId, nextId) {
  const pages = Math.max(1, Math.ceil(total / limit));
  const start = total ? (page - 1) * limit + 1 : 0;
  const end = Math.min(page * limit, total);
  byId(`${prefix}-page-label`).textContent = `Showing ${start}–${end} of ${total.toLocaleString('en-IN')}`;
  byId(prevId).disabled = page <= 1;
  byId(nextId).disabled = page >= pages;
}

function renderUserRow(user) {
  const row = make('tr');
  const nameCell = make('td'); nameCell.append(personCell(user.full_name, user.vehicle_plate));
  const plate = make('td'); setCellText(plate, user.vehicle_plate, 'plate-text');
  const uid = make('td'); setCellText(uid, user.rfid_uid, 'uid-chip');
  const status = make('td');
  const active = user.is_active !== false;
  status.append(make('span', `user-status ${active ? 'user-active' : 'user-inactive'}`, active ? (user.current_status === 'INSIDE' ? 'Inside' : 'Active') : 'Inactive'));
  const created = make('td'); setCellText(created, formatDate(user.created_at), 'time-primary');
  row.append(nameCell, plate, uid, status, created);
  return row;
}

async function loadUsers() {
  const query = new URLSearchParams({ page: String(state.userPage), limit: String(PAGE_SIZE), q: state.userQuery });
  try {
    const data = await requestJson(`/api/users?${query}`);
    const body = byId('users-body');
    body.replaceChildren(...(data.items || []).map(renderUserRow));
    byId('users-total-label').textContent = `${Number(data.total || 0).toLocaleString('en-IN')} registered parking users`;
    renderPagination('users', data.page || 1, data.total || 0, data.limit || PAGE_SIZE, 'users-prev', 'users-next');
    setEmpty('users-empty', (data.items || []).length === 0);
    if (data.setup_required) showSetupBanner('setup');
  } catch (error) {
    setConnection('is-error', 'Connection issue');
    byId('users-total-label').textContent = 'Unable to load user records';
    byId('users-body').replaceChildren();
    setEmpty('users-empty', true);
    toast(error.message, true);
  }
}

function renderEventRow(event) {
  const row = make('tr');
  const user = event.parking_user || {};
  const name = user.full_name || event.user_name;
  const vehicle = user.vehicle_plate || event.vehicle_plate;
  const userCell = make('td'); userCell.append(personCell(name, vehicle));
  const plate = make('td'); setCellText(plate, vehicle || '—', 'plate-text');
  const uid = make('td'); setCellText(uid, event.card_uid, 'uid-chip');
  const direction = make('td'); direction.append(directionChip(event.direction));
  const result = make('td'); result.append(statusChip(event.access_status));
  row.append(userCell, plate, uid, direction, result, timestampCell(event.card_tapped_at), timestampCell(event.vehicle_passed_at));
  return row;
}

async function loadEvents() {
  const query = new URLSearchParams({ page: String(state.eventPage), limit: String(PAGE_SIZE), q: state.eventQuery, direction: state.eventDirection });
  try {
    const data = await requestJson(`/api/events?${query}`);
    const body = byId('events-body');
    body.replaceChildren(...(data.items || []).map(renderEventRow));
    byId('events-total-label').textContent = `${Number(data.total || 0).toLocaleString('en-IN')} access events`;
    renderPagination('events', data.page || 1, data.total || 0, data.limit || PAGE_SIZE, 'events-prev', 'events-next');
    setEmpty('events-empty', (data.items || []).length === 0);
    if (data.setup_required) showSetupBanner('setup');
  } catch (error) {
    setConnection('is-error', 'Connection issue');
    byId('events-total-label').textContent = 'Unable to load access records';
    byId('events-body').replaceChildren();
    setEmpty('events-empty', true);
    toast(error.message, true);
  }
}

function toast(message, isError = false) {
  const node = byId('toast');
  node.textContent = message;
  node.classList.toggle('is-error', isError);
  node.classList.add('is-visible');
  window.clearTimeout(toast.timer);
  toast.timer = window.setTimeout(() => node.classList.remove('is-visible'), 3300);
}

function showView(view) {
  state.view = view;
  document.querySelectorAll('.view-section').forEach((section) => section.classList.toggle('is-current', section.id === `view-${view}`));
  document.querySelectorAll('.nav-link[data-view]').forEach((button) => button.classList.toggle('is-active', button.dataset.view === view));
  const labels = { overview: 'Overview', users: 'Parking users', events: 'Access logs' };
  byId('topbar-current').textContent = labels[view] || 'Overview';
  if (view === 'users') loadUsers();
  if (view === 'events') loadEvents();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function openUserDialog() {
  byId('form-message').classList.add('is-hidden');
  byId('form-message').textContent = '';
  byId('user-dialog').showModal();
  window.setTimeout(() => byId('add-user-form').elements.full_name.focus(), 50);
}

function closeUserDialog() { byId('user-dialog').close(); }

async function submitNewUser(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const button = byId('save-user-button');
  const message = byId('form-message');
  const formData = new FormData(form);
  const payload = Object.fromEntries(formData.entries());
  button.disabled = true;
  button.textContent = 'Saving…';
  message.classList.add('is-hidden');
  try {
    await requestJson('/api/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    form.reset();
    closeUserDialog();
    toast('Parking user added and RFID card linked.');
    await loadDashboard();
    if (state.view === 'users') { state.userPage = 1; await loadUsers(); }
  } catch (error) {
    message.textContent = error.message;
    message.classList.remove('is-hidden');
  } finally {
    button.disabled = false;
    button.innerHTML = '<span class="button-plus" aria-hidden="true">+</span> Save user';
  }
}

function setCurrentDate() {
  const now = new Date();
  const long = new Intl.DateTimeFormat('en-IN', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' }).format(now);
  const short = new Intl.DateTimeFormat('en-IN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' }).format(now);
  byId('today-label').textContent = long;
  byId('activity-date').textContent = short;
  byId('footer-year').textContent = String(now.getFullYear());
}

function bindEvents() {
  document.querySelectorAll('.nav-link[data-view]').forEach((button) => button.addEventListener('click', () => showView(button.dataset.view)));
  document.querySelectorAll('[data-view-link]').forEach((button) => button.addEventListener('click', () => showView(button.dataset.viewLink)));
  document.querySelectorAll('[data-open-user-dialog]').forEach((button) => button.addEventListener('click', openUserDialog));
  document.querySelectorAll('[data-close-user-dialog]').forEach((button) => button.addEventListener('click', closeUserDialog));
  byId('user-dialog').addEventListener('click', (event) => { if (event.target === byId('user-dialog')) closeUserDialog(); });
  byId('add-user-form').addEventListener('submit', submitNewUser);

  byId('users-prev').addEventListener('click', () => { state.userPage -= 1; loadUsers(); });
  byId('users-next').addEventListener('click', () => { state.userPage += 1; loadUsers(); });
  byId('events-prev').addEventListener('click', () => { state.eventPage -= 1; loadEvents(); });
  byId('events-next').addEventListener('click', () => { state.eventPage += 1; loadEvents(); });

  let userSearchTimer;
  byId('users-search').addEventListener('input', (event) => {
    window.clearTimeout(userSearchTimer);
    state.userQuery = event.currentTarget.value;
    state.userPage = 1;
    userSearchTimer = window.setTimeout(loadUsers, 250);
  });
  let eventSearchTimer;
  byId('events-search').addEventListener('input', (event) => {
    window.clearTimeout(eventSearchTimer);
    state.eventQuery = event.currentTarget.value;
    state.eventPage = 1;
    eventSearchTimer = window.setTimeout(loadEvents, 250);
  });
  byId('event-direction').addEventListener('change', (event) => {
    state.eventDirection = event.currentTarget.value;
    state.eventPage = 1;
    loadEvents();
  });
}

document.addEventListener('DOMContentLoaded', () => {
  setCurrentDate();
  bindEvents();
  loadDashboard();
  window.setInterval(() => {
    if (document.visibilityState !== 'visible') return;
    loadDashboard();
    if (state.view === 'users') loadUsers();
    if (state.view === 'events') loadEvents();
  }, 30000);
});
