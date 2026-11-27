// Connects Roost to Claude Code: the roost skill, the picture hook and the `roost` command.
// Usage: node src/setup.js <server folder> [node binary]. It keeps whatever is already there, so it is safe to run again.
import { execFileSync } from 'node:child_process';
import { copyFile, lstat, mkdir, readFile, rename, stat, symlink, unlink, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

export async function setup(root, node = process.execPath, home = homedir()) {
  const done = [];
  const claude = join(home, '.claude');

  const skill = join(claude, 'skills', 'roost');
  const existing = await lstat(skill).catch(() => null);
  const broken = existing?.isSymbolicLink() && !(await stat(skill).catch(() => null));
  if (existing && !broken) {
    done.push(`Kept the roost skill in ${skill}.`);
  } else {
    await mkdir(dirname(skill), { recursive: true });
    if (broken) await unlink(skill);
    await symlink(join(root, 'skills', 'roost'), skill);
    done.push('Added the roost skill.');
  }

  const settingsFile = join(claude, 'settings.json');
  const text = await readFile(settingsFile, 'utf8').catch((error) => (error.code === 'ENOENT' ? '{}' : Promise.reject(error)));
  const settings = JSON.parse(text);
  const command = `"${join(root, 'bin', 'picture-hook.sh')}"`;
  let added = 0;
  for (const event of ['UserPromptSubmit', 'Stop']) {
    const groups = (settings.hooks ??= {})[event] ??= [];
    if (groups.some((group) => group.hooks?.some((hook) => /picture-hook\.sh/.test(hook.command ?? '')))) continue;
    groups.push({ hooks: [{ type: 'command', command, timeout: 5 }] });
    added += 1;
  }
  if (added) {
    if (text !== '{}') await copyFile(settingsFile, `${settingsFile}.before-roost`);
    await mkdir(claude, { recursive: true });
    await writeFile(`${settingsFile}.tmp`, `${JSON.stringify(settings, null, 2)}\n`);
    await rename(`${settingsFile}.tmp`, settingsFile);
    done.push(`Added the picture hook to ${settingsFile}${text !== '{}' ? ' (the old file is settings.json.before-roost)' : ''}.`);
  } else {
    done.push('Kept the picture hook.');
  }

  const cli = join(home, '.local', 'bin', 'roost');
  if (await lstat(cli).catch(() => null)) {
    done.push(`Kept the roost command in ${cli}.`);
  } else {
    await mkdir(dirname(cli), { recursive: true });
    await writeFile(cli, `#!/bin/sh\nexec "${node}" "${join(root, 'bin', 'roost.js')}" "$@"\n`, { mode: 0o755 });
    done.push(`Added the roost command in ${cli}.`);
  }

  const hasJq = (() => { try { execFileSync('/bin/sh', ['-c', 'command -v jq'], { stdio: 'ignore' }); return true; } catch { return false; } })();
  if (!hasJq) done.push('The hook needs jq, which this Mac lacks. Install it with `brew install jq`.');
  return done;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [root, node] = process.argv.slice(2);
  if (!root) {
    console.error('Usage: node src/setup.js <server folder> [node binary]');
    process.exit(2);
  }
  setup(root, node).then((done) => console.log(done.join('\n')), (error) => { console.error(error.message); process.exit(1); });
}
