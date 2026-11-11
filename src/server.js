import { createServer } from 'node:http';
import { open, readFile, stat, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { basename, isAbsolute, join } from 'node:path';
import {
  applyNewOrder,
  defaultAvatar,
  deriveStatus,
  isSameProcess,
  locate,
  mergeOrder,
  parseProcesses,
  parseTabs,
  lastAiTitle,
  addTime,
  parseIdleTime,
  readSessionFiles,
  summarizeHistory,
  waitingForUs,
} from './sessions.js';
import { openStore, validatePatch, validateTopicPatch } from './store.js';
import { focusTab, listProcesses, listTabs, openViewer, readIdle, startClaude } from './terminal.js';

const PORT = Number(process.env.ROOST_PORT ?? 4777);
const HOME = process.env.ROOST_HOME ?? join(homedir(), '.roost');
const SESSIONS_DIR = process.env.ROOST_SESSIONS_DIR ?? join(homedir(), '.claude', 'sessions');
const HISTORY_FILE = process.env.ROOST_HISTORY_FILE ?? join(homedir(), '.claude', 'history.jsonl');
const LOCATION_COUNT = 5;
const RECENT_COUNT = 10;
const PROJECTS_DIR = join(homedir(), '.claude', 'projects');
const TRANSCRIPT_TAIL = 256 * 1024;
const SESSION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_BODY = 1024 * 1024;
const TABS_MAX_AGE_MS = 3000;
const FLASH_WAIT_MS = 25_000;
// Time counts between two polls, but a gap longer than this (sleep, the app closed) counts as this much.
const TIME_STEP_MAX_MS = 10_000;
// Without keyboard or mouse input for this long, a tab in front no longer counts as your time.
const AWAY_AFTER_MS = 2 * 60_000;
const TIME_SAVE_MS = 60_000;
const flashWaiters = new Set();

const store = await openStore(HOME);

let tabList = null;
let tabListAt = 0;
let tabListLoading = null;
let knownTabs = new Map();
let lastTickAt = 0;
let timeSavedAt = Date.now();
let timeUnsaved = false;

function refreshTabs() {
  tabListLoading ??= listTabs()
    .then(
      (stdout) => ({ stdout }),
      () => ({ stdout: 'false\n', failed: true }),
    )
    .then((result) => {
      tabList = result;
      tabListAt = Date.now();
      tabListLoading = null;
      return result;
    });
  return tabListLoading;
}

// A poll serves the last known tabs and never waits for Terminal.
function currentTabs() {
  if (tabList && Date.now() - tabListAt > TABS_MAX_AGE_MS) refreshTabs();
  return tabList ?? refreshTabs();
}

async function loadLive(tabSource = currentTabs()) {
  const [files, psOutput, tabOutput] = await Promise.all([readSessionFiles(SESSIONS_DIR), listProcesses(), tabSource]);
  const processes = parseProcesses(psOutput);
  const { terminalFront, tabs } = parseTabs(tabOutput.stdout);
  const live = files.filter((file) => isSameProcess(file, processes)).map((file) => ({ file, ...locate(file.pid, processes, tabs) }));
  knownTabs = new Map(live.filter(({ tab }) => tab).map(({ file, tab }) => [file.sessionId, tab]));
  return { live, terminalFront, terminalFailed: Boolean(tabOutput.failed) };
}

async function snapshot() {
  const [{ live, terminalFront, terminalFailed }, idleOutput] = await Promise.all([loadLive(), readIdle().catch(() => '')]);
  const now = Date.now();
  let changed = false;
  const step = lastTickAt ? Math.min(now - lastTickAt, TIME_STEP_MAX_MS) : 0;
  lastTickAt = now;
  const idleMs = parseIdleTime(idleOutput);
  const present = idleMs !== null && idleMs < AWAY_AFTER_MS;

  const merged = mergeOrder(store.state.order, live.map(({ file }) => file.sessionId));
  if (merged.length !== store.state.order.length) {
    store.setOrder(merged);
    changed = true;
  }

  const topicIds = new Set(store.state.topics.map((topic) => topic.id));
  const rank = new Map(store.state.order.map((id, index) => [id, index]));
  const sessions = live
    .sort((a, b) => rank.get(a.file.sessionId) - rank.get(b.file.sessionId))
    .map(({ file, tab, screenName }) => {
      const id = file.sessionId;
      let saved = store.get(id);
      const facts = { rawStatus: file.status, statusUpdatedAt: file.statusUpdatedAt, now };
      const beingWatched = terminalFront && tab?.selected && tab.windowFront;
      if (beingWatched && file.status === 'idle' && deriveStatus({ ...facts, lastSeenAt: saved.lastSeenAt }) === 'needs-me') {
        store.update(id, { lastSeenAt: now });
        saved = store.get(id);
        changed = true;
      }
      const time = addTime(saved, { step, watched: beingWatched, present, busy: file.status === 'busy' });
      if (time) {
        store.update(id, time);
        saved = store.get(id);
        timeUnsaved = true;
      }
      const tabTitle = tab && tab.title !== screenName && tab.title !== 'Terminal' ? tab.title : '';
      const title = saved.title || tabTitle || file.name || id.slice(0, 8);
      // The Recent menu shows this title once the session has ended.
      if (saved.seenTitle !== title) {
        store.update(id, { seenTitle: title });
        saved = store.get(id);
        changed = true;
      }
      return {
        id,
        pid: file.pid,
        title,
        autoTitle: tabTitle || file.name || '',
        folder: basename(file.cwd ?? ''),
        status: deriveStatus({ ...facts, snoozeUntil: saved.snoozeUntil, lastSeenAt: saved.lastSeenAt }),
        rawStatus: file.status,
        waitingFor: typeof file.waitingFor === 'string' ? file.waitingFor : null,
        since: file.statusUpdatedAt ?? null,
        openedAt: file.startedAt ?? null,
        snoozeUntil: saved.snoozeUntil ?? null,
        emoji: saved.emoji || defaultAvatar(id),
        photo: saved.photo ?? null,
        pictureSet: Boolean(saved.photo || saved.emoji),
        notes: saved.notes || null,
        waiting: waitingForUs(saved.notes),
        agentName: typeof file.name === 'string' ? file.name : null,
        notesAt: saved.notes ? (saved.notesAt ?? null) : null,
        focusMs: Math.round(saved.focusMs ?? 0),
        workMs: Math.round(saved.workMs ?? 0),
        topic: topicIds.has(saved.topic) ? saved.topic : null,
        screenName,
        openable: Boolean(tab || screenName),
      };
    });

  // The counters grow on every poll, so they reach the disk once a minute, and when the server stops.
  if (timeUnsaved && now - timeSavedAt > TIME_SAVE_MS) changed = true;
  if (changed) {
    timeUnsaved = false;
    timeSavedAt = now;
    await store.save();
  }
  return { sessions, topics: store.state.topics, terminalFailed };
}

for (const signal of ['SIGTERM', 'SIGINT', 'SIGHUP']) {
  process.on(signal, () => store.save().finally(() => process.exit(0)));
}

// The app polls every two seconds; one `ps` and one `osascript` serve every screen.
let cached = null;
function latestSnapshot() {
  cached ??= snapshot().finally(() => setTimeout(() => (cached = null), 800));
  return cached;
}

function freshSnapshotAfterWrite() {
  cached = null;
  return latestSnapshot();
}

function isTrustedRequest(req) {
  const allowedHosts = [`127.0.0.1:${PORT}`, `localhost:${PORT}`];
  if (!allowedHosts.includes(req.headers.host)) return false;
  if (req.method === 'GET') return true;
  const originOk = !req.headers.origin || allowedHosts.some((host) => req.headers.origin === `http://${host}`);
  return originOk && (req.headers['content-type'] ?? '').startsWith('application/json');
}

async function readJson(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw new Error('Body too large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
}

async function findLive(id) {
  const { live } = await loadLive(refreshTabs());
  return live.find(({ file }) => file.sessionId === id) ?? null;
}

async function openSession(id) {
  const session = await findLive(id);
  if (!session) return { status: 404, body: { error: 'This session has ended.' } };
  if (!session.tab && !session.screenName) return { status: 409, body: { error: 'This session is not in a Terminal window.' } };
  return markOpened(id, session.tab ? await focusTab(session.tab) : await openViewer(session.screenName));
}

async function markOpened(id, bounds) {
  store.update(id, { lastSeenAt: Date.now() });
  await store.save();
  flashWindow(bounds);
  return { status: 200, body: { ok: true } };
}

function flashWindow(bounds) {
  for (const finish of [...flashWaiters]) finish(bounds);
}

async function isFolder(path) {
  return stat(path).then((info) => info.isDirectory(), () => false);
}

// The history file is large and changes with every prompt, so it is read again only when it changed.
let history = { key: '', locations: [], recent: [] };
async function readHistory() {
  const info = await stat(HISTORY_FILE).catch(() => null);
  if (!info) return { locations: [], recent: [] };
  const key = `${info.mtimeMs}:${info.size}`;
  if (history.key !== key) history = { key, ...summarizeHistory(await readFile(HISTORY_FILE, 'utf8')) };
  return history;
}

async function topLocations() {
  const found = [];
  for (const path of (await readHistory()).locations) {
    if (found.length === LOCATION_COUNT) break;
    if (await isFolder(path)) found.push(path);
  }
  return found;
}

/** Reads only the end of a transcript: they grow to many megabytes, and Claude repeats its title often. */
async function claudeTitle(cwd, id) {
  const file = await open(join(PROJECTS_DIR, cwd.replace(/[^a-zA-Z0-9]/g, '-'), `${id}.jsonl`)).catch(() => null);
  if (!file) return null;
  try {
    const { size } = await file.stat();
    const length = Math.min(size, TRANSCRIPT_TAIL);
    const { buffer } = await file.read(Buffer.alloc(length), 0, length, size - length);
    return lastAiTitle(buffer.toString('utf8'));
  } finally {
    await file.close();
  }
}

/** The last sessions that no longer run, with the title the strip showed for them. */
async function recentSessions() {
  const { live } = await loadLive();
  const running = new Set(live.map(({ file }) => file.sessionId));
  const recent = [];
  for (const session of (await readHistory()).recent) {
    if (recent.length === RECENT_COUNT) break;
    if (running.has(session.id) || !SESSION_ID.test(session.id) || !(await isFolder(session.cwd))) continue;
    const saved = store.get(session.id);
    const title = saved.title || saved.seenTitle || (await claudeTitle(session.cwd, session.id)) || session.firstPrompt.slice(0, 60) || session.id.slice(0, 8);
    recent.push({ id: session.id, title, cwd: session.cwd, lastAt: session.lastAt });
  }
  return recent;
}

async function resumeSession(id) {
  const session = typeof id === 'string' && SESSION_ID.test(id) ? (await readHistory()).recent.find((candidate) => candidate.id === id) : null;
  if (!session || !(await isFolder(session.cwd))) return { status: 404, body: { error: 'Unknown session' } };
  flashWindow(await startClaude(session.cwd, session.id));
  return { status: 200, body: { ok: true } };
}

async function startSession(cwd) {
  if (typeof cwd !== 'string' || cwd.length > 1024 || !isAbsolute(cwd) || !(await isFolder(cwd))) {
    return { status: 400, body: { error: 'Bad folder' } };
  }
  flashWindow(await startClaude(cwd));
  return { status: 200, body: { ok: true } };
}

/** The remembered tab makes a click immediate; the slow lookup runs only if that tab changed. */
async function focusKnownTab(id) {
  const tab = knownTabs.get(id);
  if (!tab) return null;
  return focusTab(tab).catch(() => null);
}

/** Resolves with the bounds of the next window that a click brings forward. */
function nextFlash() {
  return new Promise((resolve) => {
    const finish = (bounds) => {
      clearTimeout(timer);
      flashWaiters.delete(finish);
      resolve(bounds);
    };
    const timer = setTimeout(() => finish(null), FLASH_WAIT_MS);
    flashWaiters.add(finish);
  });
}

async function createTopic(body) {
  const { name } = validateTopicPatch({ name: body.name });
  const sessionIds = body.sessionIds ?? [];
  if (!Array.isArray(sessionIds) || !sessionIds.every((id) => typeof id === 'string')) return { status: 400, body: { error: 'Bad sessionIds' } };
  const { live } = await loadLive();
  const liveIds = new Set(live.map(({ file }) => file.sessionId));
  const topic = store.addTopic(name);
  for (const id of sessionIds.filter((candidate) => liveIds.has(candidate))) store.update(id, { topic: topic.id });
  await store.save();
  return { status: 200, body: { id: topic.id, ...(await freshSnapshotAfterWrite()) } };
}

async function handleApi(req, url) {
  if (req.method === 'GET' && url.pathname === '/api/health') return { status: 200, body: { ok: true } };
  if (req.method === 'GET' && url.pathname === '/api/sessions') return { status: 200, body: await latestSnapshot() };
  if (req.method === 'GET' && url.pathname === '/api/flash') return { status: 200, body: { bounds: await nextFlash() } };
  if (req.method === 'GET' && url.pathname === '/api/locations') return { status: 200, body: { locations: await topLocations() } };
  if (req.method === 'GET' && url.pathname === '/api/recent') return { status: 200, body: { sessions: await recentSessions() } };

  if (req.method !== 'POST') return { status: 404, body: { error: 'Not found' } };
  const body = await readJson(req);

  if (url.pathname === '/api/order') {
    if (!Array.isArray(body.ids) || !body.ids.every((id) => typeof id === 'string')) return { status: 400, body: { error: 'Bad ids' } };
    const { live } = await loadLive();
    store.setOrder(applyNewOrder(store.state.order, body.ids, live.map(({ file }) => file.sessionId)));
    await store.save();
    return { status: 200, body: await freshSnapshotAfterWrite() };
  }

  if (url.pathname === '/api/topics') return createTopic(body);
  if (url.pathname === '/api/start') return startSession(body.cwd);
  if (url.pathname === '/api/resume') return resumeSession(body.id);

  const topicRoute = /^\/api\/topics\/([\w-]+)(\/delete)?$/.exec(url.pathname);
  if (topicRoute) {
    const [, topicId, isDelete] = topicRoute;
    if (isDelete) store.deleteTopic(topicId);
    else if (!store.updateTopic(topicId, validateTopicPatch(body))) return { status: 404, body: { error: 'Not found' } };
    await store.save();
    return { status: 200, body: await freshSnapshotAfterWrite() };
  }

  const route = /^\/api\/sessions\/([\w-]+)(?:\/(open|seen))?$/.exec(url.pathname);
  if (!route) return { status: 404, body: { error: 'Not found' } };
  const [, id, action] = route;
  if (action === 'open') {
    const bounds = await focusKnownTab(id);
    return bounds ? markOpened(id, bounds) : openSession(id);
  }
  const patch = action === 'seen' ? { lastSeenAt: Date.now() } : validatePatch(body);
  if ('notes' in patch) patch.notesAt = Date.now();
  store.update(id, patch);
  await store.save();
  return { status: 200, body: await freshSnapshotAfterWrite() };
}

const server = createServer(async (req, res) => {
  const send = (status, body) => {
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
    res.end(JSON.stringify(body));
  };
  try {
    if (!isTrustedRequest(req)) return send(403, { error: 'Forbidden' });
    const url = new URL(req.url, `http://${req.headers.host}`);
    const { status, body } = await handleApi(req, url);
    return send(status, body);
  } catch (error) {
    console.error(error.message);
    return send(error instanceof SyntaxError || /^Bad |^Expected|too large/.test(error.message) ? 400 : 500, { error: 'The request failed.' });
  }
});

server.listen(PORT, '127.0.0.1', async () => {
  await writeFile(join(HOME, 'server.pid'), String(process.pid));
  console.log(`roost listens on http://127.0.0.1:${PORT}`);
});
