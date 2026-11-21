import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { parseBounds } from './sessions.js';

const execFileAsync = promisify(execFile);
// Roost can be launched from inside a Claude Code session. Terminal and every session in it would then inherit
// that session's CLAUDE* variables, and Claude Code takes a session started with them for a child session that it keeps
// out of ~/.claude/sessions, so Roost could not see it.
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('CLAUDE')));
const run = (file, args, options = {}) => execFileAsync(file, args, { env, ...options });

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

const PAINT_TAB = `
on run argv
  tell application "Terminal"
    set t to tab ((item 2 of argv) as integer) of window id ((item 1 of argv) as integer)
    if tty of t is not (item 3 of argv) then return
    set background color of t to {(item 4 of argv) as integer, (item 5 of argv) as integer, (item 6 of argv) as integer}
    set ink to {(item 7 of argv) as integer, (item 8 of argv) as integer, (item 9 of argv) as integer}
    set normal text color of t to ink
    set bold text color of t to ink
    set cursor color of t to ink
  end tell
end run`;

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
tell application "Terminal"
  repeat with w in (get every window)
    try
      if (busy of every tab of w) does not contain true then close w
    end try
  end repeat
end tell
`;

const quote = (text) => `'${text.replaceAll("'", "'\\''")}'`;

export async function listProcesses() {
  const { stdout } = await run('/bin/ps', ['-axww', '-o', 'pid=,ppid=,tty=,lstart=,command='], { maxBuffer: 16 * 1024 * 1024 });
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

/** Opens a new Terminal window that runs Claude in the folder, resumes a session and sends a first prompt if given, and returns its bounds. */
export async function startClaude(cwd, resumeId = '', args = ['--dangerously-skip-permissions'], prompt = '', timeout = 5000) {
  const command = ['cd', quote(cwd), '&&', 'claude', ...args.map(quote), ...(resumeId ? ['--resume', quote(resumeId)] : []), ...(prompt ? [quote(prompt)] : [])].join(' ');
  const { stdout } = await run('/usr/bin/osascript', ['-e', RUN_COMMAND, command], { timeout });
  return parseBounds(stdout);
}

/** Paints a tab's background and text in two "#rrggbb" colors. Terminal takes 16-bit channels. */
export async function paintTab(tab, background, text) {
  const channels = [background, text].flatMap((hex) => [1, 3, 5].map((start) => String(parseInt(hex.slice(start, start + 2), 16) * 257)));
  await run('/usr/bin/osascript', ['-e', PAINT_TAB, String(tab.windowId), String(tab.index), `/dev/${tab.tty}`, ...channels], { timeout: 5000 });
}

/** Opens a new Terminal window that attaches to a background Claude session, and returns its bounds. */
export async function attachBackground(cwd, jobId) {
  const command = ['cd', quote(cwd), '&&', 'claude', 'attach', quote(jobId)].join(' ');
  const { stdout } = await run('/usr/bin/osascript', ['-e', RUN_COMMAND, command], { timeout: 5000 });
  return parseBounds(stdout);
}

export async function launchTerminal() {
  await run('/usr/bin/open', ['-a', 'Terminal'], { timeout: 30_000 });
}

export async function closeIdleWindows() {
  await run('/usr/bin/osascript', ['-e', CLOSE_IDLE_WINDOWS], { timeout: 20_000 });
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
