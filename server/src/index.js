// pantry-sync: the pantry app's household sync (ADR 0010).
//
// One Durable Object per household holds its records in its own SQLite
// database and handles one request at a time, so two phones syncing at once
// cannot clash. Routes (JSON):
//   POST /households                 start a household -> { household, token, code }
//   POST /h/:household/join          { code } -> { token }              (code from the first phone)
//   POST /h/:household/invite        (token) -> { code }                 a fresh join code
//   POST /h/:household/sync          (token) { since, changes[] } -> { cursor, records[] }
// The token is a long random secret kept on each phone; only its SHA-256 is
// stored. Join codes last 48 hours.

import { DurableObject } from 'cloudflare:workers';
import { invalid, mergeChange } from './merge.js';

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' };
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I/L

function randomText(n, alphabet = ALPHABET) {
  const bytes = crypto.getRandomValues(new Uint8Array(n));
  return [...bytes].map((b) => alphabet[b % alphabet.length]).join('');
}

async function sha256(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const MAX_BODY = 2 * 1024 * 1024;
const MAX_CHANGES = 2000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/') return reply({ ok: true, service: 'pantry-sync' });
    if (request.method !== 'POST') return reply({ error: 'POST only' }, 405);
    const length = Number(request.headers.get('content-length') || 0);
    if (length > MAX_BODY) return reply({ error: 'too big' }, 413);

    if (url.pathname === '/households') {
      const household = randomText(8);
      const stub = env.HOUSEHOLD.get(env.HOUSEHOLD.idFromName(household));
      return stub.fetch(new Request('https://do/create', { method: 'POST', body: JSON.stringify({ household }) }));
    }
    const m = url.pathname.match(/^\/h\/([A-Z0-9]{8})\/(join|invite|sync)$/);
    if (!m) return reply({ error: 'not found' }, 404);
    const stub = env.HOUSEHOLD.get(env.HOUSEHOLD.idFromName(m[1]));
    return stub.fetch(
      new Request('https://do/' + m[2], {
        method: 'POST',
        headers: { authorization: request.headers.get('authorization') || '' },
        body: await request.text(),
      }),
    );
  },
};

export class Household extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)`);
    this.sql.exec(`CREATE TABLE IF NOT EXISTS records (
      kind TEXT NOT NULL, id TEXT NOT NULL, data TEXT, updated_at INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0, seq INTEGER NOT NULL, PRIMARY KEY (kind, id))`);
    this.sql.exec(`CREATE INDEX IF NOT EXISTS records_seq ON records (seq)`);
  }

  meta(key) {
    const row = this.sql.exec('SELECT value FROM meta WHERE key = ?', key).toArray()[0];
    return row ? row.value : null;
  }

  setMeta(key, value) {
    this.sql.exec('INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', key, value);
  }

  async newInvite() {
    const code = randomText(6, '0123456789');
    this.setMeta('invite', code);
    this.setMeta('invite_until', String(Date.now() + 48 * 3600 * 1000));
    return `${this.meta('household')}-${code}`;
  }

  async fetch(request) {
    const route = new URL(request.url).pathname.slice(1);
    let body = {};
    try {
      const text = await request.text();
      body = text ? JSON.parse(text) : {};
    } catch {
      return reply({ error: 'bad json' }, 400);
    }

    if (route === 'create') {
      if (this.meta('token_hash')) return reply({ error: 'exists' }, 409);
      const token = randomText(40);
      this.setMeta('household', body.household);
      this.setMeta('token_hash', await sha256(token));
      this.setMeta('seq', '0');
      this.setMeta('created', new Date().toISOString());
      return reply({ household: body.household, token, code: await this.newInvite() });
    }

    if (!this.meta('token_hash')) return reply({ error: 'no such household' }, 404);

    if (route === 'join') {
      // The six digits after the dash (the household id can hold digits too).
      const code = String(body.code || '').split('-').pop().replace(/\D/g, '');
      const ok = code.length === 6 && code === this.meta('invite') && Date.now() < Number(this.meta('invite_until') || 0);
      if (!ok) return reply({ error: 'wrong or old code' }, 403);
      // A code joins once; the household token is handed to the new phone.
      this.setMeta('invite', '');
      const token = randomText(40);
      // Each phone gets the same household secret: re-issue it so the old
      // one keeps working too (stored as a second accepted hash).
      const hashes = JSON.parse(this.meta('extra_hashes') || '[]');
      hashes.push(await sha256(token));
      this.setMeta('extra_hashes', JSON.stringify(hashes.slice(-10)));
      return reply({ token });
    }

    // Everything else needs a token: the first phone's, or one a code gave out.
    const bearer = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const hash = bearer ? await sha256(bearer) : '';
    const extra = JSON.parse(this.meta('extra_hashes') || '[]');
    if (!bearer || (hash !== this.meta('token_hash') && !extra.includes(hash))) return reply({ error: 'not allowed' }, 401);

    if (route === 'invite') return reply({ code: await this.newInvite() });

    if (route === 'sync') {
      const since = Number.isFinite(body.since) ? body.since : 0;
      const changes = Array.isArray(body.changes) ? body.changes : [];
      if (changes.length > MAX_CHANGES) return reply({ error: 'too many changes' }, 413);
      let seq = Number(this.meta('seq') || 0);
      const refused = [];
      for (const c of changes) {
        const why = invalid(c);
        if (why) {
          refused.push({ kind: c && c.kind, id: c && c.id, why });
          continue;
        }
        const row = this.sql.exec('SELECT data, updated_at, deleted FROM records WHERE kind = ? AND id = ?', c.kind, c.id).toArray()[0];
        const existing = row ? { data: row.data ? JSON.parse(row.data) : null, updatedAt: row.updated_at, deleted: !!row.deleted } : null;
        const next = mergeChange(existing, c);
        if (existing && next === existing) continue;
        seq += 1;
        this.sql.exec(
          `INSERT INTO records (kind, id, data, updated_at, deleted, seq) VALUES (?, ?, ?, ?, ?, ?)
           ON CONFLICT(kind, id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at,
           deleted = excluded.deleted, seq = excluded.seq`,
          c.kind, c.id, next.data ? JSON.stringify(next.data) : null, next.updatedAt, next.deleted ? 1 : 0, seq,
        );
      }
      this.setMeta('seq', String(seq));
      const records = this.sql
        .exec('SELECT kind, id, data, updated_at, deleted, seq FROM records WHERE seq > ? ORDER BY seq', since)
        .toArray()
        .map((r) => ({ kind: r.kind, id: r.id, data: r.data ? JSON.parse(r.data) : null, updatedAt: r.updated_at, deleted: !!r.deleted, seq: r.seq }));
      return reply({ cursor: seq, records, refused });
    }

    return reply({ error: 'not found' }, 404);
  }
}
