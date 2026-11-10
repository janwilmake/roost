import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { parseBounds } from './sessions.js';

const run = promisify(execFile);

// One bulk request per property: asking tab by tab takes seconds with a dozen windows.
const LIST_TABS = `
const terminal = Application('Terminal');
const windows = terminal.windows;
const [ids, fronts, ttys, busy, selected, titles] = [windows.id(), windows.frontmost(), windows.tabs.tty(), windows.tabs.busy(), windows.tabs.selected(), windows.tabs.customTitle()];
const rows = [String(terminal.frontmost())];
ids.forEach((id, w) => ttys[w].forEach((tty, t) => {
  // A finished window keeps reporting a tty that a live window may now use.
  if (busy[w][t]) rows.push([id, t + 1, tty, selected[w][t], fronts[w], titles[w][t]].join('\\t'));
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

const START_CLAUDE = `
on run argv
  tell application "Terminal"
    do script ("cd " & quoted form of (item 1 of argv) & " && claude --dangerously-skip-permissions")
    activate
    return bounds of front window
  end tell
end run
`;

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

/** Opens a new Terminal window that runs Claude in the folder, and returns its bounds. */
export async function startClaude(cwd) {
  const { stdout } = await run('/usr/bin/osascript', ['-e', START_CLAUDE, cwd], { timeout: 5000 });
  return parseBounds(stdout);
}

/** Opens a window attached to the screen session and returns its bounds. */
export async function openViewer(screenName) {
  const { stdout } = await run('/usr/bin/osascript', ['-e', OPEN_VIEWER, screenName], { timeout: 5000 });
  return parseBounds(stdout);
}
