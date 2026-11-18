#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline/promises';
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

const USAGE = 'Usage: roost [open|stop|restart-all [--wait|--now] [--yes]]';
const SERVER = `http://127.0.0.1:${process.env.ROOST_PORT ?? 4777}/api/restart-all`;

/** Quits Terminal and opens every Claude session in it again. Roost's server does the work, so it survives the quit. */
async function restartAll(flags) {
  const known = ['--wait', '--now', '--yes'];
  if (flags.some((flag) => !known.includes(flag)) || (flags.includes('--wait') && flags.includes('--now'))) return fail(USAGE);
  const plan = await fetch(SERVER).then((response) => response.json()).catch(() => null);
  if (!plan) return fail('Roost is not running.');
  if (!plan.sessions) return fail('No Claude session runs in a Terminal tab.');
  console.log(`Terminal quits, and ${plan.sessions} Claude sessions open again; ${plan.rearm} get a prompt to start their background work again.`);
  if (plan.others.length) console.log(`These other tabs close, and what runs in them stops:\n${plan.others.map((command) => `  ${command}`).join('\n')}`);
  if (plan.viewers) console.log(`${plan.viewers} agent viewer tabs close; the agents keep running.`);
  if (plan.busy.length && !flags.includes('--wait') && !flags.includes('--now')) {
    return fail(`${plan.busy.length} session${plan.busy.length === 1 ? ' is' : 's are'} working: ${plan.busy.join(', ')}.\nRun with --wait to restart once they are done, or --now to restart them anyway.`);
  }
  if (!flags.includes('--yes')) {
    if (!process.stdin.isTTY) return fail('Add --yes to restart without this question.');
    const prompt = createInterface({ input: process.stdin, output: process.stdout });
    const answer = await prompt.question('Restart? [y/N] ');
    prompt.close();
    if (!/^y(es)?$/i.test(answer.trim())) return fail('Nothing was restarted.');
  }
  const request = { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ wait: flags.includes('--wait'), force: flags.includes('--now') }) };
  const response = await fetch(SERVER, request).catch(() => null);
  if (!response) return fail('Roost is not running.');
  const result = await response.json();
  if (!response.ok) return fail(result.error);
  console.log(`Restarting${flags.includes('--wait') && result.busy.length ? ` once ${result.busy.length} working sessions are done` : ''}. Log: ~/.roost/restart.log`);
}

function fail(message) {
  console.log(message);
  process.exitCode = 1;
}

const command = process.argv[2] ?? 'open';
if (command === 'stop') stop();
else if (command === 'restart-all') await restartAll(process.argv.slice(3));
else if (command === 'open' && existsSync(APP)) await run('/usr/bin/open', [APP]);
else if (command === 'open') {
  console.log('Roost.app is not built. Run scripts/build-app.sh first.');
  process.exitCode = 1;
} else {
  console.log(USAGE);
  process.exitCode = 1;
}
