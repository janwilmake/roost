import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';

// The directory also holds <pid>.<hash>.key secrets, which this tool must never open.
const SESSION_FILE = /^\d+\.json$/;
const CLOCK_MARGIN_MS = 5000;

const AVATARS = ['🐱', '🦊', '🐙', '🦉', '🐢', '🦔', '🐝', '🦜', '🐳', '🦦', '🐸', '🦥', '🐼', '🦩', '🐌', '🦀'];

export async function readSessionFiles(dir) {
  const names = (await readdir(dir)).filter((name) => SESSION_FILE.test(name));
  const files = await Promise.all(
    names.map(async (name) => {
      try {
        return JSON.parse(await readFile(join(dir, name), 'utf8'));
      } catch {
        return null; // Claude Code rewrites these files while we read them.
      }
    }),
  );
  return files.filter((file) => file && Number.isInteger(file.pid) && typeof file.sessionId === 'string');
}

export function deriveStatus({ rawStatus, statusUpdatedAt = 0, snoozeUntil, lastSeenAt = 0, now }) {
  if (snoozeUntil && snoozeUntil > now) return 'snoozed';
  if (rawStatus === 'busy') return 'working';
  if (rawStatus === 'shell') return 'shell';
  if (rawStatus === 'idle') return statusUpdatedAt > lastSeenAt ? 'needs-me' : 'quiet';
  return 'needs-me'; // `waiting`, and any status a future Claude Code adds: never hide those.
}

export function parseProcesses(psOutput) {
  const line = /^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\w{3} \w{3}\s+\d+ \d\d:\d\d:\d\d \d{4})\s+(.*)$/;
  const processes = new Map();
  for (const row of psOutput.split('\n')) {
    const match = line.exec(row);
    if (!match) continue;
    const [, pid, ppid, tty, started, command] = match;
    processes.set(Number(pid), { pid: Number(pid), ppid: Number(ppid), tty, startedMs: new Date(squeeze(started)).getTime(), command });
  }
  return processes;
}

/** Reads AppleScript's "left, top, right, bottom". Returns null for anything else. */
export function parseBounds(output) {
  const bounds = output.trim().split(/,\s*/).map(Number);
  return bounds.length === 4 && bounds.every(Number.isFinite) ? bounds : null;
}

export function isSameProcess(file, processes) {
  const process = processes.get(file.pid);
  if (!process) return false;
  // A stale file can name a pid that the system has given to a process started after it.
  return !file.startedAt || process.startedMs <= file.startedAt + CLOCK_MARGIN_MS;
}

export function parseTabs(output) {
  const [frontmostLine, ...rows] = output.split('\n');
  const tabs = rows
    .map((row) => row.split('\t'))
    .filter((cols) => cols.length >= 5)
    .map(([windowId, index, tty, selected, windowFront, ...title]) => ({
      windowId: Number(windowId),
      index: Number(index),
      tty: tty.replace('/dev/', ''),
      selected: selected === 'true',
      windowFront: windowFront === 'true',
      title: cleanTitle(title.join('\t')),
    }));
  return { terminalFront: frontmostLine.trim() === 'true', tabs };
}

// Claude Code prefixes the tab title with a spinner glyph that changes every frame.
export function cleanTitle(title) {
  return title.replace(/^[^\p{L}\p{N}]+/u, '').trim();
}

/** Finds where a session is shown: its own tab, or the viewer of its detached `screen`. */
export function locate(pid, processes, tabs) {
  const process = processes.get(pid);
  if (!process) return { tab: null, screenName: null };
  const tab = tabs.find((candidate) => candidate.tty === process.tty);
  if (tab) return { tab, screenName: null };
  const screenName = findScreenName(pid, processes);
  if (!screenName) return { tab: null, screenName: null };
  return { tab: findViewerTab(screenName, processes, tabs), screenName };
}

function findScreenName(pid, processes) {
  const seen = new Set();
  for (let current = processes.get(pid); current && !seen.has(current.pid); current = processes.get(current.ppid)) {
    seen.add(current.pid);
    // Anchored to the executable: a parent shell can mention `screen` in its own arguments.
    const match = /^(?:\S*\/)?screen\s.*?\s-[a-z]*S\s+([\w.-]+)/i.exec(current.command);
    if (match) return match[1];
  }
  return null;
}

function findViewerTab(screenName, processes, tabs) {
  const attach = new RegExp(`^(?:\\S*/)?screen\\s+(?:-\\S+\\s+)*-[a-z]*r\\s+${screenName.replace(/[.-]/g, '\\$&')}(?:\\s|$)`, 'i');
  for (const process of processes.values()) {
    if (!attach.test(process.command)) continue;
    const tab = tabs.find((candidate) => candidate.tty === process.tty);
    if (tab) return tab;
  }
  return null;
}

export function defaultAvatar(sessionId) {
  let hash = 0;
  for (const char of sessionId) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  return AVATARS[hash % AVATARS.length];
}

/** Folders from Claude's prompt history, most sessions first. The `cca` agent slots are left out. */
export function rankLocations(historyText) {
  const sessions = new Map();
  for (const line of historyText.split('\n')) {
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }
    if (typeof entry?.project !== 'string' || typeof entry.sessionId !== 'string') continue;
    if (entry.project.includes('/.claude/agents/')) continue;
    if (!sessions.has(entry.project)) sessions.set(entry.project, new Set());
    sessions.get(entry.project).add(entry.sessionId);
  }
  return [...sessions].sort((a, b) => b[1].size - a[1].size).map(([project]) => project);
}

/** New sessions go at the end. Ended sessions keep their place, so a resumed one returns to it. */
export function mergeOrder(order, liveIds) {
  const known = new Set(order);
  return [...order, ...liveIds.filter((id) => !known.has(id))];
}

export function applyNewOrder(order, requested, liveIds) {
  const live = new Set(liveIds);
  const front = [...new Set(requested)].filter((id) => live.has(id));
  const placed = new Set(front);
  return [...front, ...order.filter((id) => !placed.has(id))];
}

function squeeze(text) {
  return text.replace(/\s+/g, ' ').trim();
}
