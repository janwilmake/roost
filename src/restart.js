import { appendFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { restartArgs, workingTabCount } from './sessions.js';
import { closeIdleWindows, launchTerminal, listTabs, quitTerminal, startClaude, terminalRunning } from './terminal.js';

const POLL_MS = 2000;
const WAIT_MAX_MS = 60 * 60_000;
const STOP_WAIT_MS = 15_000;
// Terminal shows a dialog when a window still runs something else; the user answers it.
const QUIT_WAIT_MS = 5 * 60_000;
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
      windowId: tab.windowId,
      busy: file.status === 'busy',
      title: titleOf(file.sessionId),
      // Crons and loop wakeups have no process, so the wip mark and the counts of the notes stand in for them.
      shells: shellChildren(file.pid, processes),
      rearm: shellChildren(file.pid, processes).length > 0 || hadWork(file),
    }))
    .sort((a, b) => (rank.get(a.id) ?? Infinity) - (rank.get(b.id) ?? Infinity));
}

export function restartPlan(targets) {
  return { running, sessions: targets.length, rearm: targets.filter((target) => target.rearm).length, busy: targets.filter((target) => target.busy).map((target) => target.title) };
}

/** Starts the restart and answers at once: the work goes on after Terminal, and the client that asked, have quit. */
export function restartAll(targets, { wait = false, force = false, collect, logFile }) {
  if (running) return { status: 409, body: { error: 'A restart is already running.' } };
  if (!targets.length) return { status: 409, body: { error: 'No Claude session runs in a Terminal tab.' } };
  const plan = restartPlan(targets);
  if (plan.busy.length && !wait && !force) return { status: 409, body: { error: 'Some sessions are working. Ask again with wait or force.', ...plan } };
  running = true;
  const log = (line) => appendFile(logFile, `${new Date().toISOString()} ${line}\n`).catch(() => {});
  run({ wait, collect, log })
    .catch((error) => log(`failed: ${error.message}`))
    .finally(() => (running = false));
  return { status: 202, body: { ...plan, running: true } };
}

async function run({ wait, collect, log }) {
  let targets = await collect();
  const waitUntil = Date.now() + WAIT_MAX_MS;
  while (wait && targets.some((target) => target.busy)) {
    if (Date.now() > waitUntil) throw new Error('sessions were still working after an hour; nothing was stopped');
    await delay(POLL_MS);
    targets = await collect();
  }
  log(`stopping ${targets.length} sessions: ${targets.map((target) => target.id).join(' ')}`);

  // SIGHUP is what a closed window sends; Claude Code has written the transcript by then.
  for (const signal of ['SIGHUP', 'SIGTERM']) {
    for (const target of targets.filter(isAlive)) signalPid(target.pid, signal);
    const stopBy = Date.now() + STOP_WAIT_MS;
    while (targets.some(isAlive) && Date.now() < stopBy) await delay(250);
  }
  const left = targets.filter(isAlive);
  if (left.length) log(`still running, resumed anyway: ${left.map((target) => target.id).join(' ')}`);
  // A background shell runs in a process group of its own, so it can outlive its session; the resumed session starts it again.
  const orphans = targets.flatMap((target) => target.shells).filter((pid) => isAlive({ pid }));
  for (const pid of orphans) signalGroup(pid, 'SIGTERM');
  if (orphans.length) log(`stopped ${orphans.length} background shells that outlived their session`);

  // From here every step goes on after an error: the sessions are stopped and must open again.
  await closeIdleWindows([...new Set(targets.map((target) => target.windowId))]).catch((error) => log(`could not close windows: ${error.message}`));
  await quitTerminal();
  const quitBy = Date.now() + QUIT_WAIT_MS;
  while ((await terminalRunning()) && Date.now() < quitBy) await delay(500);
  // The sessions are stopped now, so they open again even when Terminal did not quit.
  if (await terminalRunning()) log('Terminal did not quit; the sessions open in the running Terminal');

  // Terminal runs fully before the first window opens, so no `do script` waits on its start.
  await launchTerminal().catch((error) => log(`could not launch Terminal: ${error.message}`));
  const launchBy = Date.now() + LAUNCH_WAIT_MS;
  while (!(await terminalRunning()) && Date.now() < launchBy) await delay(500);
  await delay(2000);

  for (const target of targets) {
    if (target.rearm) await waitForSlot();
    await startClaude(target.cwd, target.id, target.args, target.rearm ? REARM_PROMPT : '', START_TIMEOUT_MS).catch((error) => log(`could not resume ${target.id}: ${error.message}`));
    await delay(START_GAP_MS);
  }
  log(`resumed ${targets.length} sessions, ${targets.filter((target) => target.rearm).length} with the prompt to start their work again`);
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
