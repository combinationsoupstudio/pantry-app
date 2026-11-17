// pantry-sync: the pantry app's household sync (ADR 0010).
//
// One Durable Object per household holds its records in its own SQLite
// database and handles one request at a time, so two phones syncing at once
// cannot clash. Routes (JSON):
//   POST /households                 start a household -> { household, token, code }
//   POST /h/:household/join          { code } -> { token }              (code from the first phone)
//   POST /h/:household/invite        (token) -> { code }                 a fresh join code
//   POST /h/:household/sync          (token) { since, changes[], phone } -> { cursor, records[] }
//   GET  /h/:household/live          (token) websocket: { cursor, from } is sent the moment the
//                                    household changes; the phone then syncs. "ping" -> "pong".
//   PUT  /h/:household/photo         (token) a JPEG -> { hash }          the household's own photos
//   GET  /h/:household/photo/:hash   (token) the JPEG
// The product library (v0.13), one for everyone, by barcode:
//   GET  /catalogue/:barcode         -> { product } or 404               open: a barcode is no secret
//   GET  /catalogue/:barcode/photo   -> the JPEG                          open
//   POST /catalogue/:barcode         (token + x-household) { name, ... } what a household set it up as
//   PUT  /catalogue/:barcode/photo   (token + x-household) a JPEG
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
const MAX_PHOTO = 600 * 1024;
const BARCODE = /^\d{6,14}$/;

async function sha256Bytes(buf) {
  const d = await crypto.subtle.digest('SHA-256', buf);
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const isJpeg = (buf) => buf.byteLength > 3 && new Uint8Array(buf, 0, 3).every((b, i) => b === [0xff, 0xd8, 0xff][i]);

const jpeg = (data) =>
  new Response(data, { headers: { 'content-type': 'image/jpeg', 'cache-control': 'public, max-age=31536000, immutable' } });

/** Does this bearer token belong to that household? */
async function householdAllows(env, household, request) {
  if (!/^[A-Z0-9]{8}$/.test(household || '')) return false;
  const stub = env.HOUSEHOLD.get(env.HOUSEHOLD.idFromName(household));
  const res = await stub.fetch(
    new Request('https://do/check', { method: 'POST', headers: { authorization: request.headers.get('authorization') || '' } }),
  );
  return res.status === 200;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/') return reply({ ok: true, service: 'pantry-sync' });
    const live = url.pathname.match(/^\/h\/([A-Z0-9]{8})\/live$/);
    if (live && request.method === 'GET') {
      if (request.headers.get('upgrade') !== 'websocket') return reply({ error: 'websocket only' }, 426);
      const stub = env.HOUSEHOLD.get(env.HOUSEHOLD.idFromName(live[1]));
      return stub.fetch(new Request('https://do/live', request));
    }
    const length = Number(request.headers.get('content-length') || 0);

    // Household photos.
    const photo = url.pathname.match(/^\/h\/([A-Z0-9]{8})\/photo(?:\/([0-9a-f]{64}))?$/);
    if (photo) {
      const stub = env.HOUSEHOLD.get(env.HOUSEHOLD.idFromName(photo[1]));
      const auth = { authorization: request.headers.get('authorization') || '' };
      if (request.method === 'GET' && photo[2]) {
        return stub.fetch(new Request('https://do/photo-get', { method: 'POST', headers: auth, body: JSON.stringify({ hash: photo[2] }) }));
      }
      if (request.method === 'PUT' && !photo[2]) {
        if (length > MAX_PHOTO) return reply({ error: 'photo too big' }, 413);
        const data = await request.arrayBuffer();
        if (data.byteLength > MAX_PHOTO || !isJpeg(data)) return reply({ error: 'a JPEG under 600 KB, please' }, 400);
        return stub.fetch(new Request('https://do/photo-put', { method: 'POST', headers: auth, body: data }));
      }
      return reply({ error: 'not found' }, 404);
    }

    // The product library.
    const cat = url.pathname.match(/^\/catalogue\/(\d{6,14})(\/photo)?$/);
    if (cat) {
      const stub = env.CATALOGUE.get(env.CATALOGUE.idFromName('everyone'));
      const [, barcode, isPhoto] = cat;
      if (request.method === 'GET') {
        return stub.fetch(new Request(`https://do/${isPhoto ? 'photo-get' : 'get'}?barcode=${barcode}`));
      }
      const writes = isPhoto ? request.method === 'PUT' : request.method === 'POST';
      if (!writes) return reply({ error: 'not found' }, 404);
      if (!(await householdAllows(env, request.headers.get('x-household'), request))) return reply({ error: 'not allowed' }, 401);
      if (isPhoto) {
        if (length > MAX_PHOTO) return reply({ error: 'photo too big' }, 413);
        const data = await request.arrayBuffer();
        if (data.byteLength > MAX_PHOTO || !isJpeg(data)) return reply({ error: 'a JPEG under 600 KB, please' }, 400);
        return stub.fetch(new Request(`https://do/photo-put?barcode=${barcode}`, { method: 'POST', body: data }));
      }
      if (length > 16 * 1024) return reply({ error: 'too big' }, 413);
      return stub.fetch(new Request(`https://do/put?barcode=${barcode}`, { method: 'POST', body: await request.text() }));
    }

    if (request.method !== 'POST') return reply({ error: 'POST only' }, 405);
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
    // Keep-alive pings are answered without waking the household.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  async allowed(request) {
    if (!this.meta('token_hash')) return false;
    const bearer = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    if (!bearer) return false;
    const hash = await sha256(bearer);
    const extra = JSON.parse(this.meta('extra_hashes') || '[]');
    return hash === this.meta('token_hash') || extra.includes(hash);
  }

  // The household's own photos, by the SHA-256 of the JPEG (so a photo is
  // stored once, and a phone can name it before it is uploaded).
  async photo(route, request) {
    if (!(await this.allowed(request))) return reply({ error: 'not allowed' }, 401);
    this.sql.exec(`CREATE TABLE IF NOT EXISTS photos (hash TEXT PRIMARY KEY, data BLOB NOT NULL, at INTEGER NOT NULL)`);
    if (route === 'photo-put') {
      const data = await request.arrayBuffer();
      const hash = await sha256Bytes(data);
      this.sql.exec(`INSERT OR IGNORE INTO photos (hash, data, at) VALUES (?, ?, ?)`, hash, data, Date.now());
      return reply({ hash });
    }
    const { hash } = await request.json();
    const row = this.sql.exec(`SELECT data FROM photos WHERE hash = ?`, String(hash)).toArray()[0];
    return row ? jpeg(row.data) : reply({ error: 'no such photo' }, 404);
  }

  // Tells every open phone the household moved on (each then syncs).
  tell(cursor, from) {
    const note = JSON.stringify({ cursor, from: from || null });
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(note);
      } catch {
        // A phone that has gone drops off by itself.
      }
    }
  }

  async webSocketMessage() {}

  async webSocketClose(ws, code, reason) {
    try {
      ws.close(code, reason);
    } catch {
    }
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
    if (route.startsWith('photo')) return this.photo(route, request);
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

    if (route === 'check') return reply({ ok: true });
    if (route === 'invite') return reply({ code: await this.newInvite() });

    if (route === 'live') {
      if (request.headers.get('upgrade') !== 'websocket') return reply({ error: 'websocket only' }, 426);
      const [client, server] = Object.values(new WebSocketPair());
      this.ctx.acceptWebSocket(server);
      server.send(JSON.stringify({ cursor: Number(this.meta('seq') || 0), from: null }));
      return new Response(null, { status: 101, webSocket: client });
    }

    if (route === 'sync') {
      const since = Number.isFinite(body.since) ? body.since : 0;
      const changes = Array.isArray(body.changes) ? body.changes : [];
      if (changes.length > MAX_CHANGES) return reply({ error: 'too many changes' }, 413);
      let seq = Number(this.meta('seq') || 0);
      const before = seq;
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
      if (seq > before) this.tell(seq, typeof body.phone === 'string' ? body.phone.slice(0, 40) : null);
      const records = this.sql
        .exec('SELECT kind, id, data, updated_at, deleted, seq FROM records WHERE seq > ? ORDER BY seq', since)
        .toArray()
        .map((r) => ({ kind: r.kind, id: r.id, data: r.data ? JSON.parse(r.data) : null, updatedAt: r.updated_at, deleted: !!r.deleted, seq: r.seq }));
      return reply({ cursor: seq, records, refused });
    }

    return reply({ error: 'not found' }, 404);
  }
}

// What a household set a barcode up as, cleaned to known fields.
function cleanProduct(p) {
  if (!p || typeof p !== 'object') return null;
  const text = (v, n) => (typeof v === 'string' ? v.trim().slice(0, n) : '');
  const num = (v) => (Number.isFinite(Number(v)) && Number(v) >= 0 && Number(v) < 1e6 ? Number(v) : 0);
  const name = text(p.name, 120);
  if (!name) return null;
  return {
    name,
    brand: text(p.brand, 80),
    packSize: num(p.packSize),
    unit: text(p.unit, 12),
    countAs: p.countAs === 'measure' ? 'measure' : 'count',
    countUnit: text(p.countUnit, 24),
    locationKind: p.locationKind === 'storage' ? 'storage' : 'pantry',
    source: p.source === 'off' ? 'off' : 'household',
  };
}

// The product library: one for everyone, by barcode. A household's set-up
// wins over what Open Food Facts said; the latest household's wins over an
// earlier one. Photos are kept one per barcode, the latest.
export class Catalogue extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`CREATE TABLE IF NOT EXISTS products (
      barcode TEXT PRIMARY KEY, data TEXT NOT NULL, source TEXT NOT NULL, updated_at INTEGER NOT NULL, uses INTEGER NOT NULL DEFAULT 0)`);
    this.sql.exec(`CREATE TABLE IF NOT EXISTS photos (barcode TEXT PRIMARY KEY, data BLOB NOT NULL, at INTEGER NOT NULL)`);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const route = url.pathname.slice(1);
    const barcode = url.searchParams.get('barcode') || '';
    if (!BARCODE.test(barcode)) return reply({ error: 'bad barcode' }, 400);
    if (route === 'get') {
      const row = this.sql.exec(`SELECT data, updated_at FROM products WHERE barcode = ?`, barcode).toArray()[0];
      if (!row) return reply({ error: 'unknown' }, 404);
      const hasPhoto = this.sql.exec(`SELECT 1 FROM photos WHERE barcode = ?`, barcode).toArray().length > 0;
      return reply({ product: { barcode, ...JSON.parse(row.data), hasPhoto, updatedAt: row.updated_at } });
    }
    if (route === 'photo-get') {
      const row = this.sql.exec(`SELECT data FROM photos WHERE barcode = ?`, barcode).toArray()[0];
      return row ? jpeg(row.data) : reply({ error: 'no photo' }, 404);
    }
    if (route === 'photo-put') {
      const data = await request.arrayBuffer();
      this.sql.exec(
        `INSERT INTO photos (barcode, data, at) VALUES (?, ?, ?) ON CONFLICT(barcode) DO UPDATE SET data = excluded.data, at = excluded.at`,
        barcode, data, Date.now(),
      );
      return reply({ ok: true });
    }
    if (route === 'put') {
      let p;
      try {
        p = cleanProduct(JSON.parse(await request.text()));
      } catch {
        p = null;
      }
      if (!p) return reply({ error: 'needs a name' }, 400);
      const old = this.sql.exec(`SELECT source FROM products WHERE barcode = ?`, barcode).toArray()[0];
      // What Open Food Facts said never replaces what a household set up.
      if (old && old.source === 'household' && p.source === 'off') return reply({ ok: true, kept: true });
      const { source, ...data } = p;
      this.sql.exec(
        `INSERT INTO products (barcode, data, source, updated_at, uses) VALUES (?, ?, ?, ?, 1)
         ON CONFLICT(barcode) DO UPDATE SET data = excluded.data, source = excluded.source,
         updated_at = excluded.updated_at, uses = products.uses + 1`,
        barcode, JSON.stringify(data), source, Date.now(),
      );
      return reply({ ok: true });
    }
    return reply({ error: 'not found' }, 404);
  }
}
