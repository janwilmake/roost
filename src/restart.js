import { appendFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { parseProcesses, restartArgs, workingTabCount } from './sessions.js';
import { closeIdleWindows, launchTerminal, listProcesses, listTabs, quitTerminal, startClaude, terminalRunning } from './terminal.js';

const POLL_MS = 2000;
const WAIT_MAX_MS = 60 * 60_000;
const STOP_WAIT_MS = 15_000;
// Roost stops what runs in the other windows first, so Terminal has nothing to ask; a Terminal that still does not quit is ended.
const QUIT_WAIT_MS = 30_000;
const KILL_WAIT_MS = 10_000;
const OTHER_STOP_WAIT_MS = 5000;
// Every session must show as live this long after the last one opened, or it opens once more.
const CHECK_WAIT_MS = 90_000;
const TERMINAL_APP = /\/Terminal\.app\/Contents\/MacOS\/Terminal$/;
// Every resumed session takes memory, and one with the prompt also works a turn; 35 at once can fill the memory of a laptop.
const START_GAP_MS = 3000;
const MAX_WORKING = 4;
const SLOT_WAIT_MS = 2 * 60_000;
const LAUNCH_WAIT_MS = 30_000;
// A window opened while Terminal still starts up can take longer than one opened later.
const START_TIMEOUT_MS = 30_000;
export const REARM_PROMPT =
  'Roost restarted Terminal, so this session was stopped and resumed. Its background shells, monitors, session crons and /loop wakeups are gone. ' +
  'If this session had any of them running, start them again now, the same way as before. If none was running, end the turn without doing anything.';

let running = false;

/**
 * The Claude sessions that run in a Terminal tab, in strip order. A session in a detached `screen`, such as a cca agent,
 * survives a Terminal quit, so it is not one of them.
 */
export function restartTargets({ live, processes }, order, titleOf, hadWork) {
  const rank = new Map(order.map((id, index) => [id, index]));
  return live
    .filter(({ tab, screenName }) => tab && !screenName)
    .map(({ file, tab }) => ({
      id: file.sessionId,
      pid: file.pid,
      cwd: file.cwd,
      args: restartArgs(processes.get(file.pid)?.command ?? ''),
      tty: tab.tty,
      busy: file.status === 'busy',
      title: titleOf(file.sessionId),
      // Crons and loop wakeups have no process, so the wip mark and the counts of the notes stand in for them.
      shells: shellChildren(file.pid, processes),
      rearm: shellChildren(file.pid, processes).length > 0 || hadWork(file),
    }))
    .sort((a, b) => (rank.get(a.id) ?? Infinity) - (rank.get(b.id) ?? Infinity));
}

/** What a restart closes: the Claude sessions, and every other Terminal tab that still runs something. */
export function restartScene(loaded, order, titleOf, hadWork) {
  const targets = restartTargets(loaded, order, titleOf, hadWork);
  return { targets, others: otherTabs(loaded, targets) };
}

/** The tabs that run something other than a restarted session, with the processes on them; a `screen -r` tab is a viewer. */
export function otherTabs({ tabs, processes }, targets) {
  const sessionTtys = new Set(targets.map((target) => target.tty));
  return tabs
    .filter((tab) => !sessionTtys.has(tab.tty))
    .map((tab) => {
      const running = [...processes.values()].filter((proc) => proc.tty === tab.tty && !/^(?:\S*\/)?login\s/.test(proc.command));
      const shells = new Set(running.filter((proc) => /^-?(?:\S*\/)?(?:zsh|bash|sh)$/.test(proc.command)).map((proc) => proc.pid));
      // The tab is named after the job its shell started, not after a helper that runs on the tab for a moment.
      const jobs = running.filter((proc) => !shells.has(proc.pid));
      const shown = jobs.find((proc) => shells.has(proc.ppid)) ?? jobs[0];
      return { tty: tab.tty, pids: running.map((proc) => proc.pid), command: (shown?.command ?? tab.title).slice(0, 60), viewer: /^(?:\S*\/)?screen\s/.test(shown?.command ?? '') };
    })
    .filter((tab) => tab.pids.length);
}

export function restartPlan({ targets, others }) {
  return {
    running,
    sessions: targets.length,
    rearm: targets.filter((target) => target.rearm).length,
    busy: targets.filter((target) => target.busy).map((target) => target.title),
    others: others.filter((tab) => !tab.viewer).map((tab) => tab.command),
    viewers: others.filter((tab) => tab.viewer).length,
  };
}

/** Starts the restart and answers at once: the work goes on after Terminal, and the client that asked, have quit. */
export function restartAll(scene, { wait = false, force = false, collect, liveIds, logFile }) {
  if (running) return { status: 409, body: { error: 'A restart is already running.' } };
  if (!scene.targets.length) return { status: 409, body: { error: 'No Claude session runs in a Terminal tab.' } };
  const plan = restartPlan(scene);
  if (plan.busy.length && !wait && !force) return { status: 409, body: { error: 'Some sessions are working. Ask again with wait or force.', ...plan } };
  running = true;
  const log = (line) => appendFile(logFile, `${new Date().toISOString()} ${line}\n`).catch(() => {});
  run({ wait, collect, liveIds, log })
    .catch((error) => log(`failed: ${error.message}`))
    .finally(() => (running = false));
  return { status: 202, body: { ...plan, running: true } };
}

async function run({ wait, collect, liveIds, log }) {
  let { targets } = await collect();
  const waitUntil = Date.now() + WAIT_MAX_MS;
  while (wait && targets.some((target) => target.busy)) {
    if (Date.now() > waitUntil) throw new Error('sessions were still working after an hour; nothing was stopped');
    await delay(POLL_MS);
    ({ targets } = await collect());
  }
  log(`stopping ${targets.length} sessions: ${targets.map((target) => target.id).join(' ')}`);

  // SIGHUP is what a closed window sends; Claude Code has written the transcript by then.
  await stopAll(targets.map((target) => target.pid), STOP_WAIT_MS);
  const left = targets.filter(isAlive);
  if (left.length) log(`still running, resumed anyway: ${left.map((target) => target.id).join(' ')}`);
  // A background shell runs in a process group of its own, so it can outlive its session; the resumed session starts it again.
  const orphans = targets.flatMap((target) => target.shells).filter((pid) => isAlive({ pid }));
  for (const pid of orphans) signalGroup(pid, 'SIGTERM');
  if (orphans.length) log(`stopped ${orphans.length} background shells that outlived their session`);

  // From here every step goes on after an error: the sessions are stopped and must open again.
  // The user agreed to close the other windows too. Stopping their processes here means Terminal shows no dialog,
  // which a late click could answer after the sessions have opened again.
  const { others } = await collect().catch(() => ({ others: [] }));
  await stopAll(others.flatMap((tab) => tab.pids), OTHER_STOP_WAIT_MS);
  if (others.length) log(`stopped what ran in ${others.length} other tabs`);
  await closeIdleWindows().catch((error) => log(`could not close windows: ${error.message}`));
  await quitTerminal();
  if (!(await until(async () => !(await terminalRunning()), QUIT_WAIT_MS))) {
    log('Terminal did not quit; ending it');
    const app = await terminalPid();
    if (app) await stopAll([app], KILL_WAIT_MS, ['SIGTERM', 'SIGKILL']);
    await until(async () => !(await terminalRunning()), KILL_WAIT_MS);
  }

  // Terminal runs fully before the first window opens, so no `do script` waits on its start.
  await launchTerminal().catch((error) => log(`could not launch Terminal: ${error.message}`));
  await until(terminalRunning, LAUNCH_WAIT_MS);
  await delay(2000);

  await openAll(targets, log);
  log(`resumed ${targets.length} sessions, ${targets.filter((target) => target.rearm).length} with the prompt to start their work again`);

  for (const round of ['missing', 'still missing']) {
    const missing = await missingSessions(targets, liveIds);
    if (!missing.length) return log('every session is back');
    log(`${round}: ${missing.map((target) => target.id).join(' ')}`);
    if (round === 'missing') await openAll(missing, log);
  }
}

async function openAll(targets, log) {
  for (const target of targets) {
    if (target.rearm) await waitForSlot();
    await startClaude(target.cwd, target.id, target.args, target.rearm ? REARM_PROMPT : '', START_TIMEOUT_MS).catch((error) => log(`could not resume ${target.id}: ${error.message}`));
    await delay(START_GAP_MS);
  }
}

/** The sessions that did not come back: no live session file and no claude process that resumes them. */
async function missingSessions(targets, liveIds) {
  let missing = targets;
  await until(async () => {
    const [live, processes] = await Promise.all([liveIds(), listProcesses().then(parseProcesses)]);
    const resuming = [...processes.values()].map((proc) => proc.command).filter((command) => /(?:^|\/)claude\s/.test(command));
    missing = targets.filter((target) => !live.has(target.id) && !resuming.some((command) => command.includes(target.id)));
    return !missing.length;
  }, CHECK_WAIT_MS);
  return missing;
}

async function until(check, ms) {
  const by = Date.now() + ms;
  for (;;) {
    if (await check().catch(() => false)) return true;
    if (Date.now() > by) return false;
    await delay(1000);
  }
}

async function stopAll(pids, ms, signals = ['SIGHUP', 'SIGTERM']) {
  for (const signal of signals) {
    for (const pid of pids.filter((pid) => isAlive({ pid }))) signalPid(pid, signal);
    await until(async () => !pids.some((pid) => isAlive({ pid })), ms);
  }
}

async function terminalPid() {
  const processes = parseProcesses(await listProcesses().catch(() => ''));
  return [...processes.values()].find((proc) => TERMINAL_APP.test(proc.command))?.pid ?? null;
}

async function waitForSlot() {
  const by = Date.now() + SLOT_WAIT_MS;
  while (Date.now() < by && workingTabCount(await listTabs().catch(() => '')) >= MAX_WORKING) await delay(1000);
}

/** A background shell of Claude Code runs as a shell child of its claude process; MCP servers do not. */
export function shellChildren(pid, processes) {
  return [...processes.values()].filter((child) => child.ppid === pid && /^(?:\S*\/)?(?:zsh|bash|sh)\s/.test(child.command)).map((child) => child.pid);
}

function isAlive({ pid }) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function signalGroup(pid, signal) {
  try {
    process.kill(-pid, signal);
  } catch {
    signalPid(pid, signal);
  }
}

function signalPid(pid, signal) {
  try {
    process.kill(pid, signal);
  } catch {}
}
