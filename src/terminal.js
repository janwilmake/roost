import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { parseBounds } from './sessions.js';

const run = promisify(execFile);

// One bulk request per property: asking tab by tab takes seconds with a dozen windows.
const LIST_TABS = `
const terminal = Application('Terminal');
const windows = terminal.windows;
// frontmost() is false for every window while another app is in front; index 1 is the top window either way.
const [ids, order, ttys, busy, selected, titles] = [windows.id(), windows.index(), windows.tabs.tty(), windows.tabs.busy(), windows.tabs.selected(), windows.tabs.customTitle()];
const rows = [String(terminal.frontmost())];
ids.forEach((id, w) => ttys[w].forEach((tty, t) => {
  // A finished window keeps reporting a tty that a live window may now use.
  if (busy[w][t]) rows.push([id, t + 1, tty, selected[w][t], order[w] === 1, titles[w][t]].join('\\t'));
}));
rows.join('\\n');
`;

const FOCUS_TAB = `
on run argv
  tell application "Terminal"
    set w to window id (item 1 of argv as integer)
    set t to tab (item 2 of argv as integer) of w
    if tty of t is not (item 3 of argv) then error "This tab now shows another session."
    set miniaturized of w to false
    set selected tab of w to t
    set index of w to 1
    activate
    return bounds of w
  end tell
end run
`;

const OPEN_VIEWER = `
on run argv
  tell application "Terminal"
    do script ("exec /usr/bin/screen -r " & quoted form of (item 1 of argv))
    activate
    return bounds of front window
  end tell
end run
`;

const RUN_COMMAND = `
on run argv
  tell application "Terminal"
    do script (item 1 of argv)
    activate
    return bounds of front window
  end tell
end run
`;

// A window that only holds idle shells closes without Terminal asking first.
const CLOSE_IDLE_WINDOWS = `
on run argv
  tell application "Terminal"
    repeat with windowId in argv
      try
        set w to window id (windowId as integer)
        if (busy of every tab of w) does not contain true then close w
      end try
    end repeat
  end tell
end run
`;

const quote = (text) => `'${text.replaceAll("'", "'\\''")}'`;

export async function listProcesses() {
  const { stdout } = await run('/bin/ps', ['-axww', '-o', 'pid=,ppid=,tty=,lstart=,command='], { maxBuffer: 16 * 1024 * 1024 });
  return stdout;
}

/** Returns the raw `ioreg` output that holds the time since the last keyboard or mouse input. */
export async function readIdle() {
  const { stdout } = await run('/usr/sbin/ioreg', ['-c', 'IOHIDSystem', '-d', '4', '-r', '-k', 'HIDIdleTime'], { timeout: 2000 });
  return stdout;
}

export async function listTabs() {
  const { stdout } = await run('/usr/bin/osascript', ['-l', 'JavaScript', '-e', LIST_TABS], { timeout: 5000 });
  return stdout;
}

/** Brings the tab to the front and returns the window's bounds. */
export async function focusTab(tab) {
  const { stdout } = await run('/usr/bin/osascript', ['-e', FOCUS_TAB, String(tab.windowId), String(tab.index), `/dev/${tab.tty}`], { timeout: 5000 });
  return parseBounds(stdout);
}

/** Opens a new Terminal window that runs Claude in the folder, resumes a session if given, and returns its bounds. */
export async function startClaude(cwd, resumeId = '', args = ['--dangerously-skip-permissions']) {
  const command = ['cd', quote(cwd), '&&', 'claude', ...args.map(quote), ...(resumeId ? ['--resume', quote(resumeId)] : [])].join(' ');
  const { stdout } = await run('/usr/bin/osascript', ['-e', RUN_COMMAND, command], { timeout: 5000 });
  return parseBounds(stdout);
}

export async function closeIdleWindows(windowIds) {
  if (windowIds.length) await run('/usr/bin/osascript', ['-e', CLOSE_IDLE_WINDOWS, ...windowIds.map(String)], { timeout: 10_000 });
}

/** Asks Terminal to quit. When a window still runs something, Terminal asks the user first, so this does not wait for the answer. */
export async function quitTerminal() {
  await run('/usr/bin/osascript', ['-e', 'tell application "Terminal" to quit'], { timeout: 5000 }).catch(() => {});
}

export async function terminalRunning() {
  // An answer that fails counts as running, so a restart waits rather than opening sessions in a Terminal that quits.
  const answer = await run('/usr/bin/osascript', ['-e', 'application "Terminal" is running'], { timeout: 5000 }).catch(() => ({ stdout: 'true' }));
  return answer.stdout.trim() === 'true';
}

/** Opens a window attached to the screen session and returns its bounds. */
export async function openViewer(screenName) {
  const { stdout } = await run('/usr/bin/osascript', ['-e', OPEN_VIEWER, screenName], { timeout: 5000 });
  return parseBounds(stdout);
}
