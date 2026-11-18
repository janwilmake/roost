#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

const HOME = process.env.ROOST_HOME ?? join(homedir(), '.roost');
const APP = join(homedir(), 'Applications', 'Roost.app');
const run = promisify(execFile);

function stop() {
  const pidFile = join(HOME, 'server.pid');
  if (!existsSync(pidFile)) return console.log('roost is not running.');
  try {
    process.kill(Number(readFileSync(pidFile, 'utf8')));
    console.log('roost stopped.');
  } catch {
    console.log('roost was not running.');
  }
  rmSync(pidFile);
}

const SERVER = `http://127.0.0.1:${process.env.ROOST_PORT ?? 4777}/api/restart-all`;

/** Quits Terminal and opens every Claude session in it again. Roost's server does the work, so it survives the quit. */
async function restartAll(flag) {
  const request = { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ wait: flag === '--wait', force: flag === '--now' }) };
  const response = await fetch(SERVER, request).catch(() => null);
  if (!response) return fail('Roost is not running.');
  const result = await response.json();
  if (response.ok) return console.log(`Restarting ${result.sessions} sessions, ${result.rearm} with a prompt to start their background work again${flag === '--wait' && result.busy.length ? ` once ${result.busy.length} working ones are done` : ''}. Log: ~/.roost/restart.log`);
  if (result.busy?.length) return fail(`${result.busy.length} session${result.busy.length === 1 ? " is" : "s are"} working: ${result.busy.join(', ')}.\nRun with --wait to restart once they are done, or --now to restart them anyway.`);
  fail(result.error);
}

function fail(message) {
  console.log(message);
  process.exitCode = 1;
}

const command = process.argv[2] ?? 'open';
if (command === 'stop') stop();
else if (command === 'restart-all' && [undefined, '--wait', '--now'].includes(process.argv[3])) await restartAll(process.argv[3]);
else if (command === 'open' && existsSync(APP)) await run('/usr/bin/open', [APP]);
else if (command === 'open') {
  console.log('Roost.app is not built. Run scripts/build-app.sh first.');
  process.exitCode = 1;
} else {
  console.log('Usage: roost [open|stop|restart-all [--wait|--now]]');
  process.exitCode = 1;
}
