import assert from 'node:assert/strict';
import { test } from 'node:test';
import { applyNewOrder, parseBounds, cleanTitle, deriveStatus, isSameProcess, locate, mergeOrder, parseProcesses, parseTabs, summarizeHistory, lastAiTitle, waitingForUs, addTime, parseIdleTime, ruleSnoozes, ruleSnoozeEnd } from '../src/sessions.js';
import { validatePatch, validateTopicPatch } from '../src/store.js';

const NOW = 1_000_000;
const STARTED = 'Tue Nov 10 10:42:38 2026';

function ps(rows) {
  return rows.map(([pid, ppid, tty, command]) => `${pid} ${ppid} ${tty} ${STARTED}     ${command}`).join('\n');
}

test('status: only busy is working, and a running shell command is its own state', () => {
  assert.equal(deriveStatus({ rawStatus: 'busy', now: NOW }), 'working');
  assert.equal(deriveStatus({ rawStatus: 'shell', now: NOW }), 'shell');
});

test('status: idle needs me until I saw it', () => {
  assert.equal(deriveStatus({ rawStatus: 'idle', statusUpdatedAt: 500, lastSeenAt: 400, now: NOW }), 'needs-me');
  assert.equal(deriveStatus({ rawStatus: 'idle', statusUpdatedAt: 500, lastSeenAt: 600, now: NOW }), 'quiet');
});

test('status: waiting and unknown values always need me', () => {
  assert.equal(deriveStatus({ rawStatus: 'waiting', statusUpdatedAt: 500, lastSeenAt: 600, now: NOW }), 'needs-me');
  assert.equal(deriveStatus({ rawStatus: 'brand-new', now: NOW }), 'needs-me');
});

test('status: snooze wins until it expires', () => {
  assert.equal(deriveStatus({ rawStatus: 'waiting', snoozeUntil: NOW + 1, now: NOW }), 'snoozed');
  assert.equal(deriveStatus({ rawStatus: 'waiting', snoozeUntil: NOW - 1, now: NOW }), 'needs-me');
});

test('a stale file that names a reused pid is not live', () => {
  const processes = parseProcesses(ps([[10, 1, 'ttys001', 'claude']]));
  const startedMs = new Date(STARTED).getTime();
  assert.equal(isSameProcess({ pid: 10, startedAt: startedMs + 3000 }, processes), true);
  assert.equal(isSameProcess({ pid: 10, startedAt: startedMs - 3_600_000 }, processes), false);
  assert.equal(isSameProcess({ pid: 11 }, processes), false);
});

test('parseBounds reads window bounds, also on a screen with negative coordinates', () => {
  assert.deepEqual(parseBounds('-471, -1388, 729, -22\n'), [-471, -1388, 729, -22]);
  assert.equal(parseBounds(''), null);
  assert.equal(parseBounds('missing value'), null);
});

test('tab titles lose the spinner glyph', () => {
  assert.equal(cleanTitle('✳ Sense recruitment requests'), 'Sense recruitment requests');
  assert.equal(cleanTitle('◐ Aurinko contact'), 'Aurinko contact');
});

test('parseTabs reads the AppleScript output', () => {
  const { terminalFront, tabs } = parseTabs('true\n42\t1\t/dev/ttys005\ttrue\tfalse\t✳ Hello\n');
  assert.equal(terminalFront, true);
  assert.deepEqual(tabs, [{ windowId: 42, index: 1, tty: 'ttys005', selected: true, windowFront: false, title: 'Hello' }]);
});

test('locate finds the tab of a plain terminal session', () => {
  const processes = parseProcesses(ps([[10, 1, 'ttys005', 'claude']]));
  const tab = { tty: 'ttys005', windowId: 1, index: 1 };
  assert.deepEqual(locate(10, processes, [tab]), { tab, screenName: null });
});

const SCREEN_TREE = [
  [50, 1, '??', '/usr/bin/screen -T screen-256color -dmS agent-3 /bin/zsh -lic exec /bin/bash /x/agent-3.command'],
  [51, 50, 'ttys020', '/bin/bash /x/agent-3.command'],
  [52, 51, 'ttys020', 'claude --dangerously-skip-permissions'],
];

test('locate finds the viewer tab of a cca agent', () => {
  const processes = parseProcesses(ps([...SCREEN_TREE, [60, 2, 'ttys007', '/usr/bin/screen -r agent-3']]));
  const tab = { tty: 'ttys007', windowId: 2, index: 1 };
  assert.deepEqual(locate(52, processes, [tab]), { tab, screenName: 'agent-3' });
});

test('locate reports a cca agent with no viewer', () => {
  const processes = parseProcesses(ps([...SCREEN_TREE, [60, 2, 'ttys007', '/usr/bin/screen -r agent-30']]));
  assert.deepEqual(locate(52, processes, [{ tty: 'ttys007', windowId: 2, index: 1 }]), { tab: null, screenName: 'agent-3' });
});

test('a shell that only mentions screen in its arguments is not a screen session', () => {
  const processes = parseProcesses(ps([
    [70, 1, '??', "/bin/zsh -c eval '/usr/bin/screen -dmS roost-test /bin/sleep 9'"],
    [71, 70, '??', 'claude'],
  ]));
  assert.deepEqual(locate(71, processes, []), { tab: null, screenName: null });
});

test('history gives folders by session count and sessions by last use, without agent slots', () => {
  const line = (project, sessionId, timestamp, display = 'x') => JSON.stringify({ project, sessionId, timestamp, display });
  const history = [
    line('/w/a', '1', 10, 'first prompt'), line('/w/a', '1', 50),
    line('/w/b', '2', 20), line('/w/b', '3', 30),
    line('/Users/x/.claude/agents/agent-1', '4', 99), line('/Users/x/.claude/agents/agent-1', '5', 98),
    'not json', '',
  ].join('\n');
  const { locations, recent } = summarizeHistory(history);
  assert.deepEqual(locations, ['/w/b', '/w/a']);
  assert.deepEqual(recent.map(({ id }) => id), ['1', '3', '2']);
  assert.deepEqual(recent[0], { id: '1', cwd: '/w/a', firstPrompt: 'first prompt', lastAt: 50 });
});

test('the last AI title in a transcript wins, and a cut-off line is skipped', () => {
  const text = '{"type":"ai-title","aiTitle":"Old"}\n{"type":"ai-title","aiTitle":"New \\"one\\""}\n{"type":"ai-title","aiTitle":"Cut';
  assert.equal(lastAiTitle(text), 'New "one"');
  assert.equal(lastAiTitle('nothing here'), null);
});

test('the badge counts the header, or else the items waiting for you', () => {
  assert.equal(waitingForUs('Waiting for us: 2 · Waiting for them: 5\nAbout: x'), 2);
  assert.equal(waitingForUs('Acme — Waiting for us: 1\nGlobex — Waiting for us: 3'), 4);
  assert.equal(waitingForUs('About: x\nWaiting for you:\n- a\n- b\nWaiting for others:\n- c'), 2);
  assert.equal(waitingForUs('About: nothing waits'), 0);
  assert.equal(waitingForUs(null), 0);
  assert.equal(waitingForUs('Late: 1 · Waiting for us: 4 · Waiting for them: 2'), 1);
  assert.equal(waitingForUs('Acme — Late: 0 · Waiting for us: 3\nGlobex — Late: 2 · Waiting for us: 1'), 2);
});

test('new sessions go at the end, and ended sessions keep their place', () => {
  assert.deepEqual(mergeOrder(['a', 'gone', 'b'], ['b', 'new', 'a']), ['a', 'gone', 'b', 'new']);
});

test('a reorder ignores unknown ids and keeps ended sessions', () => {
  assert.deepEqual(applyNewOrder(['a', 'gone', 'b'], ['b', 'evil', 'a'], ['a', 'b']), ['b', 'a', 'gone']);
});

test('topic fields are validated', () => {
  assert.deepEqual(validateTopicPatch({ name: '  Customers ', collapsed: true, id: 'x' }), { name: 'Customers', collapsed: true });
  assert.throws(() => validateTopicPatch({ name: '   ' }));
  assert.throws(() => validateTopicPatch({ collapsed: 'yes' }));
  assert.deepEqual(validatePatch({ topic: null }), { topic: null });
  assert.throws(() => validatePatch({ topic: 5 }));
});

test('validatePatch keeps only known fields and rejects bad values', () => {
  assert.deepEqual(validatePatch({ title: 'x', description: 'y', lastSeenAt: 5 }), { title: 'x' });
  assert.throws(() => validatePatch({ photo: 'javascript:alert(1)' }));
  assert.throws(() => validatePatch({ snoozeUntil: 'soon' }));
  assert.deepEqual(validatePatch({ photo: null, snoozeUntil: null }), { photo: null, snoozeUntil: null });
  assert.deepEqual(validatePatch({ notes: '  Waits for the client. ' }), { notes: 'Waits for the client.' });
  assert.throws(() => validatePatch({ notes: 'x'.repeat(3001) }));
});

test('time counts while the tab is in front and someone is there, and while Claude works', () => {
  assert.deepEqual(addTime({}, { step: 2000, watched: true, present: true, busy: false }), { focusMs: 2000 });
  assert.deepEqual(addTime({ focusMs: 5, workMs: 10 }, { step: 2000, watched: true, present: true, busy: true }), { focusMs: 2005, workMs: 2010 });
  assert.equal(addTime({}, { step: 2000, watched: true, present: false, busy: false }), null);
  assert.equal(addTime({}, { step: 0, watched: true, present: true, busy: true }), null);
  assert.equal(parseIdleTime('  |   "HIDIdleTime" = 8626958000\n'), 8626.958);
  assert.equal(parseIdleTime(''), null);
});

test('repeating snoozes follow the local week, and end on the first hour they no longer hold', () => {
  const wednesday10 = new Date(2026, 10, 11, 10, 30);
  const wednesday20 = new Date(2026, 10, 11, 20, 0);
  const saturday = new Date(2026, 10, 14, 12, 0);
  assert.equal(ruleSnoozes(['workday'], wednesday10), true);
  assert.equal(ruleSnoozes(['workday'], wednesday20), false);
  assert.equal(ruleSnoozes(['week'], saturday), false);
  assert.equal(ruleSnoozes(['weekend'], saturday), true);
  assert.equal(ruleSnoozeEnd(['workday'], wednesday10), new Date(2026, 10, 11, 18, 0).getTime());
  assert.equal(ruleSnoozeEnd(['weekend'], saturday), new Date(2026, 10, 16, 0, 0).getTime());
  assert.equal(ruleSnoozeEnd(['week', 'weekend'], saturday), null);
  assert.equal(deriveStatus({ rawStatus: 'waiting', snoozedByRule: true, now: NOW }), 'snoozed');
  assert.deepEqual(validatePatch({ snoozeRules: ['week', 'week'] }), { snoozeRules: ['week'] });
  assert.throws(() => validatePatch({ snoozeRules: ['always'] }));
});
