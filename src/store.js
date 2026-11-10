import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const LIMITS = { emoji: 32, title: 200, notes: 3000, photo: 400_000, topicName: 80, topicId: 64 };

export async function openStore(home) {
  await mkdir(home, { recursive: true, mode: 0o700 });
  const file = join(home, 'state.json');
  let state = { order: [], sessions: {}, topics: [] };
  try {
    state = { ...state, ...JSON.parse(await readFile(file, 'utf8')) };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }

  let writing = Promise.resolve();
  const save = () => {
    writing = writing.then(async () => {
      const temporary = `${file}.tmp`;
      await writeFile(temporary, JSON.stringify(state, null, 2), { mode: 0o600 });
      await rename(temporary, file);
    });
    return writing;
  };

  return {
    state,
    get: (id) => state.sessions[id] ?? {},
    save,
    setOrder(order) {
      state.order = order;
    },
    update(id, fields) {
      state.sessions[id] = { ...state.sessions[id], ...fields };
    },
    addTopic(name) {
      const topic = { id: randomUUID(), name, collapsed: false };
      state.topics.push(topic);
      return topic;
    },
    updateTopic(id, fields) {
      const topic = state.topics.find((candidate) => candidate.id === id);
      if (topic) Object.assign(topic, fields);
      return Boolean(topic);
    },
    deleteTopic(id) {
      state.topics = state.topics.filter((topic) => topic.id !== id);
      for (const session of Object.values(state.sessions)) {
        if (session.topic === id) delete session.topic;
      }
    },
  };
}

/** Returns only the topic fields that a client may set, or throws on a bad value. */
export function validateTopicPatch(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Expected an object');
  const patch = {};
  if ('name' in body) {
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (!name || name.length > LIMITS.topicName) throw new Error('Bad name');
    patch.name = name;
  }
  if ('collapsed' in body) {
    if (typeof body.collapsed !== 'boolean') throw new Error('Bad collapsed');
    patch.collapsed = body.collapsed;
  }
  return patch;
}

/** Returns only the fields that a client may set, or throws on a bad value. */
export function validatePatch(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Expected an object');
  const patch = {};
  for (const key of ['emoji', 'title']) {
    if (!(key in body)) continue;
    if (typeof body[key] !== 'string' || body[key].length > LIMITS[key]) throw new Error(`Bad ${key}`);
    patch[key] = body[key];
  }
  if ('notes' in body) {
    if (body.notes !== null && (typeof body.notes !== 'string' || body.notes.length > LIMITS.notes)) throw new Error('Bad notes');
    patch.notes = body.notes === null ? null : body.notes.trim();
  }
  if ('photo' in body) {
    const valid = body.photo === null || (typeof body.photo === 'string' && body.photo.length <= LIMITS.photo && /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(body.photo));
    if (!valid) throw new Error('Bad photo');
    patch.photo = body.photo;
  }
  if ('topic' in body) {
    if (body.topic !== null && (typeof body.topic !== 'string' || body.topic.length > LIMITS.topicId)) throw new Error('Bad topic');
    patch.topic = body.topic;
  }
  if ('snoozeUntil' in body) {
    if (body.snoozeUntil !== null && !Number.isFinite(body.snoozeUntil)) throw new Error('Bad snoozeUntil');
    patch.snoozeUntil = body.snoozeUntil;
  }
  return patch;
}
