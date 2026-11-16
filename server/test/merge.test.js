import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeChange, invalid } from '../src/merge.js';

const item = (quantity, extra = {}) => ({ id: 'a', name: 'Rice', quantity, unit: 'kg', ...extra });

test('a new record is taken as sent', () => {
  const r = mergeChange(null, { kind: 'items', id: 'a', data: item(3), updatedAt: 10, qtyDelta: 3 });
  assert.deepEqual(r, { data: item(3), updatedAt: 10, deleted: false });
});

test('two phones changing a count both count', () => {
  const server = { data: item(5), updatedAt: 10, deleted: false };
  // Chris used 1 (5 -> 4) at t=20; Emily added 2 (5 -> 7) at t=21, from the same 5.
  const afterChris = mergeChange(server, { kind: 'items', id: 'a', data: item(4), updatedAt: 20, qtyDelta: -1 });
  const afterEmily = mergeChange(afterChris, { kind: 'items', id: 'a', data: item(7), updatedAt: 21, qtyDelta: 2 });
  assert.equal(afterEmily.data.quantity, 6);
  assert.equal(afterEmily.updatedAt, 21);
});

test('the later edit wins other fields; an older edit still brings its count', () => {
  const server = { data: item(5, { name: 'White rice' }), updatedAt: 30, deleted: false };
  const r = mergeChange(server, { kind: 'items', id: 'a', data: item(4, { name: 'Rice' }), updatedAt: 20, qtyDelta: -1 });
  assert.equal(r.data.name, 'White rice', 'older rename loses');
  assert.equal(r.data.quantity, 4, 'its use still counts');
  assert.equal(r.updatedAt, 30);
});

test('counts never go below zero', () => {
  const r = mergeChange({ data: item(1), updatedAt: 1, deleted: false }, { kind: 'items', id: 'a', data: item(0), updatedAt: 2, qtyDelta: -3 });
  assert.equal(r.data.quantity, 0);
});

test('a later delete removes; a later edit brings it back', () => {
  const del = mergeChange({ data: item(2), updatedAt: 1, deleted: false }, { kind: 'items', id: 'a', updatedAt: 5, deleted: true });
  assert.deepEqual(del, { data: null, updatedAt: 5, deleted: true });
  const back = mergeChange(del, { kind: 'items', id: 'a', data: item(3), updatedAt: 6, qtyDelta: 3 });
  assert.equal(back.deleted, false);
  assert.equal(back.data.quantity, 3);
});

test('prices and activity are never changed or deleted once written', () => {
  const p = { data: { total: 4.5 }, updatedAt: 1, deleted: false };
  assert.equal(mergeChange(p, { kind: 'prices', id: 'p', data: { total: 9 }, updatedAt: 9 }), p);
  assert.equal(mergeChange(p, { kind: 'activity', id: 'p', updatedAt: 9, deleted: true }), p);
});

test('bad changes are refused', () => {
  assert.equal(invalid({ kind: 'items', id: 'a', data: {}, updatedAt: 1 }), null);
  assert.equal(invalid({ kind: 'secrets', id: 'a', data: {}, updatedAt: 1 }), 'unknown kind');
  assert.equal(invalid({ kind: 'items', id: '', data: {}, updatedAt: 1 }), 'bad id');
  assert.equal(invalid({ kind: 'items', id: 'a', updatedAt: 1 }), 'no data');
  assert.equal(invalid({ kind: 'items', id: 'a', data: {}, updatedAt: 'x' }), 'bad updatedAt');
});
