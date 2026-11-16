// Merge rules for the pantry household (ADR 0010). Pure functions, no
// Cloudflare: tested with `node --test` (server/test).
//
// A record is { data, updatedAt, deleted } stored per (kind, id).
// A change from a phone is { kind, id, data, updatedAt, deleted, qtyDelta? }.
//
// - Last write wins per record, by updatedAt (ms).
// - Stock quantity merges by DELTA: two phones changing the same item's
//   count both count (Chris uses 1 while Emily adds 2 = +1).
// - Prices and activity are append-only: once written, never changed or
//   deleted by a phone (history is never lost to a sync).

export const KINDS = new Set(['locations', 'items', 'shopping', 'recipes', 'prices', 'activity', 'settings']);
export const APPEND_ONLY = new Set(['prices', 'activity']);

const round = (n) => Math.round(n * 1000) / 1000;

/** Checks a change's shape; returns an error string, or null when it is fine. */
export function invalid(change) {
  if (!change || typeof change !== 'object') return 'not an object';
  if (!KINDS.has(change.kind)) return 'unknown kind';
  if (typeof change.id !== 'string' || change.id.length < 1 || change.id.length > 200) return 'bad id';
  if (!Number.isFinite(change.updatedAt)) return 'bad updatedAt';
  if (!change.deleted && (change.data === null || typeof change.data !== 'object')) return 'no data';
  if (change.qtyDelta !== undefined && !Number.isFinite(change.qtyDelta)) return 'bad qtyDelta';
  return null;
}

/** The record after [change] lands on [existing] (null when there was none). */
export function mergeChange(existing, change) {
  if (!existing) {
    return { data: change.deleted ? null : change.data, updatedAt: change.updatedAt, deleted: !!change.deleted };
  }
  if (APPEND_ONLY.has(change.kind)) return existing;

  const wins = change.updatedAt >= existing.updatedAt;
  const rec = wins
    ? { data: change.deleted ? null : change.data, updatedAt: change.updatedAt, deleted: !!change.deleted }
    : { ...existing };

  if (change.kind === 'items' && Number.isFinite(change.qtyDelta) && !rec.deleted && rec.data) {
    const base = existing.deleted || !existing.data ? 0 : Number(existing.data.quantity) || 0;
    rec.data = { ...rec.data, quantity: round(Math.max(0, base + change.qtyDelta)) };
  }
  return rec;
}
