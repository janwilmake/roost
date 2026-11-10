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

const command = process.argv[2] ?? 'open';
if (command === 'stop') stop();
else if (command === 'open' && existsSync(APP)) await run('/usr/bin/open', [APP]);
else if (command === 'open') {
  console.log('Roost.app is not built. Run scripts/build-app.sh first.');
  process.exitCode = 1;
} else {
  console.log('Usage: roost [open|stop]');
  process.exitCode = 1;
}
