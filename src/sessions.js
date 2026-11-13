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
  return files.filter(isShownSession);
}

/** A session that someone works in. A headless `claude -p` run (entrypoint `sdk-cli`) has no window to open, so the strip skips it. */
export function isShownSession(file) {
  return Boolean(file) && Number.isInteger(file.pid) && typeof file.sessionId === 'string' && file.entrypoint !== 'sdk-cli';
}

export function deriveStatus({ rawStatus, statusUpdatedAt = 0, snoozeUntil, snoozedByRule = false, wip = false, lastSeenAt = 0, now }) {
  if ((snoozeUntil && snoozeUntil > now) || snoozedByRule) return 'snoozed';
  if (rawStatus === 'busy') return 'working';
  if (rawStatus === 'shell') return 'shell';
  if (rawStatus === 'idle' && wip) return 'wip';
  if (rawStatus === 'idle') return statusUpdatedAt > lastSeenAt ? 'needs-me' : 'quiet';
  return 'needs-me'; // `waiting`, and any status a future Claude Code adds: never hide those.
}

/** A wip mark older than this stops hiding the session, in case the work it waits on died silently. */
export const WIP_MAX_MS = 6 * 3600_000;
const WIP_CLEARED = { wip: null, wipAt: null, wipBase: null, wipEndAt: null };

/** The wip fields to save when a session gets a wip mark, given its session file at that moment. */
export function wipStart(text, { status, statusUpdatedAt }, now) {
  // Set from inside a turn: the mark holds through the end of that turn. Set while idle: it holds from now.
  return { wip: text, wipAt: now, wipBase: statusUpdatedAt ?? null, wipEndAt: status === 'idle' ? (statusUpdatedAt ?? null) : null };
}

/**
 * What a poll does to a wip mark: null to keep it, or the fields to save.
 * The mark ends when the session starts a new turn after the one that set it: the work it waited on came back,
 * or the user typed. A turn that still waits sets it again.
 */
export function wipChange(saved, { status, statusUpdatedAt }, now) {
  if (saved.wip == null) return null;
  if (!(now - saved.wipAt <= WIP_MAX_MS)) return WIP_CLEARED;
  if (statusUpdatedAt === saved.wipBase) return null;
  if (saved.wipEndAt == null) return status === 'idle' ? { wipEndAt: statusUpdatedAt } : null;
  return statusUpdatedAt === saved.wipEndAt ? null : WIP_CLEARED;
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

/**
 * Reads Claude's prompt history. `locations` are folders, most sessions first. `recent` are sessions,
 * most recently used first. The `cca` agent slots are left out of both.
 */
export function summarizeHistory(historyText) {
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
    const at = Number.isFinite(entry.timestamp) ? entry.timestamp : 0;
    const known = sessions.get(entry.sessionId);
    if (known) known.lastAt = Math.max(known.lastAt, at);
    else sessions.set(entry.sessionId, { id: entry.sessionId, cwd: entry.project, firstPrompt: String(entry.display ?? ''), lastAt: at });
  }
  const perFolder = new Map();
  for (const { cwd } of sessions.values()) perFolder.set(cwd, (perFolder.get(cwd) ?? 0) + 1);
  return {
    locations: [...perFolder].sort((a, b) => b[1] - a[1]).map(([cwd]) => cwd),
    recent: [...sessions.values()].sort((a, b) => b.lastAt - a.lastAt),
  };
}

/**
 * The number in the badge: the sum of the "Late: N" counts of the customer headers, or else of their
 * "Waiting for us: N" counts, or else the items in the "Waiting for you" list of the notes.
 */
export function waitingForUs(notes) {
  if (!notes) return 0;
  const late = [...notes.matchAll(/(?:^|[\s·—-])Late:\s*(\d+)/gm)];
  if (late.length) return late.reduce((sum, match) => sum + Number(match[1]), 0);
  const headers = [...notes.matchAll(/Waiting for us:\s*(\d+)/gi)];
  if (headers.length) return headers.reduce((sum, match) => sum + Number(match[1]), 0);
  let inList = false;
  let count = 0;
  for (const line of notes.split('\n')) {
    if (/^\s*Waiting for you:/i.test(line)) inList = true;
    else if (/^\s*[-*•]\s+\S/.test(line)) count += inList ? 1 : 0;
    else if (line.trim()) inList = false;
  }
  return count;
}

/**
 * The number behind the blue dot: what a teammate was asked to do, so it waits neither on the user nor on the
 * customer. The sum of the "Waiting for team: N" counts of the customer headers, or else the items in the
 * "Waiting for team" list of the notes.
 */
export function waitingForTeam(notes) {
  if (!notes) return 0;
  const headers = [...notes.matchAll(/Waiting for team:[ \t]*(\d+)/gi)];
  if (headers.length) return headers.reduce((sum, match) => sum + Number(match[1]), 0);
  let inList = false;
  let count = 0;
  for (const line of notes.split('\n')) {
    if (/^\s*Waiting for team:\s*$/i.test(line)) inList = true;
    else if (/^\s*[-*•]\s+\S/.test(line)) count += inList ? 1 : 0;
    else if (line.trim()) inList = false;
  }
  return count;
}

/**
 * What the user handed to the session itself: the sum of the "In progress: N" header fields, or else the items
 * in the "In progress:" list of the notes. With nothing waiting for the user, the tile shows the gray wip badge
 * for as long as the notes say so; no turn boundary clears it.
 */
export function inProgress(notes) {
  if (!notes) return 0;
  const headers = [...notes.matchAll(/(?:^|·[ \t]*|—[ \t]*)In progress:[ \t]*(\d+)/gm)];
  if (headers.length) return headers.reduce((sum, match) => sum + Number(match[1]), 0);
  let inList = false;
  let count = 0;
  for (const line of notes.split('\n')) {
    if (/^\s*In progress:\s*$/i.test(line)) inList = true;
    else if (/^\s*[-*•]\s+\S/.test(line)) count += inList ? 1 : 0;
    else if (line.trim()) inList = false;
  }
  return count;
}

/** Finds the last title that Claude Code wrote into a transcript. */
export function lastAiTitle(transcriptText) {
  let title = null;
  for (const match of transcriptText.matchAll(/"type":"ai-title","aiTitle":("(?:[^"\\]|\\.)*")/g)) {
    try {
      title = JSON.parse(match[1]);
    } catch {
      // A cut-off line at the edge of the part that was read.
    }
  }
  return title;
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

/** Reads the time since the last keyboard or mouse input, in ms, from `ioreg -c IOHIDSystem`. */
export function parseIdleTime(text) {
  const match = /"HIDIdleTime" = (\d+)/.exec(text ?? '');
  return match ? Number(match[1]) / 1e6 : null;
}

/**
 * Adds one poll's time to a session's counters: `focusMs` while its tab is in front and someone uses the Mac,
 * `workMs` while Claude works. Returns the new counters, or null when neither grew.
 */
export function addTime(saved, { step, watched, present, busy }) {
  if (!(step > 0)) return null;
  const patch = {};
  if (watched && present) patch.focusMs = (saved.focusMs ?? 0) + step;
  if (busy) patch.workMs = (saved.workMs ?? 0) + step;
  return Object.keys(patch).length ? patch : null;
}

/**
 * Repeating snoozes, in the Mac's local time: `week` is Monday to Friday, `workday` is Monday to Friday
 * from 9:00 to 18:00, and `weekend` is Saturday and Sunday.
 */
export const SNOOZE_RULES = ['week', 'workday', 'weekend'];

export function ruleSnoozes(rules, date) {
  const day = date.getDay();
  const hour = date.getHours();
  const weekday = day >= 1 && day <= 5;
  return (rules ?? []).some((rule) =>
    (rule === 'week' && weekday) || (rule === 'workday' && weekday && hour >= 9 && hour < 18) || (rule === 'weekend' && !weekday));
}

/** When the repeating snooze that holds now ends, or null when the rules never end (every day). */
export function ruleSnoozeEnd(rules, date) {
  if (!ruleSnoozes(rules, date)) return null;
  // Every rule starts and ends on a full hour.
  const next = new Date(date);
  next.setMinutes(0, 0, 0);
  for (let hours = 1; hours <= 8 * 24; hours += 1) {
    next.setHours(next.getHours() + 1);
    if (!ruleSnoozes(rules, next)) return next.getTime();
  }
  return null;
}

/** Moves a session that joins a topic to just after the topic's last session, so the topic keeps its place. */
export function moveIntoTopic(order, id, memberIds) {
  const members = new Set(memberIds);
  members.delete(id);
  const rest = order.filter((other) => other !== id);
  const last = rest.findLastIndex((other) => members.has(other));
  if (last === -1) return order;
  return [...rest.slice(0, last + 1), id, ...rest.slice(last + 1)];
}
