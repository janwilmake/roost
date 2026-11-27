import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readlink, writeFile, mkdir, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setup } from '../src/setup.js';

test('setup adds the skill, both hooks and the command once, and keeps other settings', async () => {
  const home = await mkdtemp(join(tmpdir(), 'roost-setup-'));
  await mkdir(join(home, '.claude'));
  await writeFile(join(home, '.claude', 'settings.json'), JSON.stringify({ model: 'opus', hooks: { Stop: [{ hooks: [{ type: 'command', command: 'other.sh' }] }] } }));
  await setup('/Applications/Roost.app/Contents/Resources/server', '/node', home);
  await setup('/Applications/Roost.app/Contents/Resources/server', '/node', home);

  const settings = JSON.parse(await readFile(join(home, '.claude', 'settings.json'), 'utf8'));
  assert.equal(settings.model, 'opus');
  assert.equal(settings.hooks.UserPromptSubmit.length, 1);
  assert.equal(settings.hooks.Stop.length, 2);
  assert.match(settings.hooks.Stop[1].hooks[0].command, /Resources\/server\/bin\/picture-hook\.sh"$/);
  assert.ok(await stat(join(home, '.claude', 'settings.json.before-roost')));
  assert.equal(await readlink(join(home, '.claude', 'skills', 'roost')), '/Applications/Roost.app/Contents/Resources/server/skills/roost');
  assert.match(await readFile(join(home, '.local', 'bin', 'roost'), 'utf8'), /exec "\/node" ".*\/bin\/roost\.js" "\$@"/);
});

test('setup keeps a hook from a clone', async () => {
  const home = await mkdtemp(join(tmpdir(), 'roost-setup-'));
  await mkdir(join(home, '.claude'));
  const clone = { hooks: [{ type: 'command', command: '/Users/me/roost/bin/picture-hook.sh' }] };
  await writeFile(join(home, '.claude', 'settings.json'), JSON.stringify({ hooks: { UserPromptSubmit: [clone], Stop: [clone] } }));
  const done = await setup('/x', '/node', home);
  assert.ok(done.includes('Kept the picture hook.'));
});
