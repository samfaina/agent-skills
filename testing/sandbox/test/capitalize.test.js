import { test } from 'node:test';
import assert from 'node:assert/strict';
import { capitalize } from '../src/index.js';

test('capitalize upper-cases the first character', () => {
  assert.equal(capitalize('hello world'), 'Hello world');
});

test('capitalize leaves an empty string empty', () => {
  assert.equal(capitalize(''), '');
});
