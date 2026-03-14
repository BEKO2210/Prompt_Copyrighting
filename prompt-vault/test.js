#!/usr/bin/env node

/**
 * Prompt-Vault test suite.
 * Tests encryption/decryption, watermark embed/extract, and auth hashing.
 *
 * Usage: node test.js
 */

import { encryptVault, decryptVault } from './lib/promptManager.js';
import { embed, extract, strip } from './lib/watermark.js';
import { hashToken } from './lib/auth.js';
import { unlinkSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const TEST_VAULT = join(__dirname, 'test-vault.enc');

let passed = 0;
let failed = 0;

function assert(condition, name) {
  if (condition) {
    console.log(`  PASS  ${name}`);
    passed++;
  } else {
    console.error(`  FAIL  ${name}`);
    failed++;
  }
}

// ─── Encryption / Decryption ───────────────────────────────────────────────

console.log('\n--- Vault Encryption ---');

const testPrompts = [
  {
    id: 'test-1',
    name: 'Test Prompt',
    author: 'Test Author',
    copyright: '(c) 2024 Test',
    version: '1.0.0',
    content: 'Write a poem about {{topic}}.',
  },
  {
    id: 'test-2',
    name: 'Another Prompt',
    author: 'Test Author',
    copyright: '(c) 2024 Test',
    version: '1.0.0',
    content: 'Translate {{text}} to {{language}}.',
  },
];

const secret = 'test-secret-key-do-not-use-in-production';

// Encrypt
const encResult = encryptVault(testPrompts, secret, TEST_VAULT);
assert(encResult.count === 2, 'Encrypt returns correct count');
assert(existsSync(TEST_VAULT), 'Vault file created');

// Decrypt
const decrypted = decryptVault(secret, TEST_VAULT);
assert(decrypted.length === 2, 'Decrypt returns correct count');
assert(decrypted[0].id === 'test-1', 'First prompt ID matches');
assert(decrypted[1].content === 'Translate {{text}} to {{language}}.', 'Second prompt content matches');

// Wrong secret should fail
let wrongSecretFailed = false;
try {
  decryptVault('wrong-secret', TEST_VAULT);
} catch {
  wrongSecretFailed = true;
}
assert(wrongSecretFailed, 'Wrong secret throws error');

// Cleanup
unlinkSync(TEST_VAULT);

// ─── Watermark ─────────────────────────────────────────────────────────────

console.log('\n--- Watermark ---');

const original = 'This is a test response. It contains multiple sentences for watermark insertion.';
const watermarked = embed(original, 'test-prompt-1', { token: 'abc12345' });

assert(watermarked.length > original.length, 'Watermarked text is longer than original');
assert(strip(watermarked) === original, 'Stripped watermark equals original');

const payload = extract(watermarked);
assert(payload !== null, 'Watermark extracted successfully');
assert(payload?.pid === 'test-prompt-1', 'Extracted prompt ID matches');
assert(payload?.token === 'abc12345', 'Extracted token matches');
assert(typeof payload?.ts === 'number', 'Timestamp is a number');

// Tampered text should still extract (watermark chars preserved)
const tampered = watermarked.replace('test response', 'modified response');
const tamperedPayload = extract(tampered);
assert(tamperedPayload?.pid === 'test-prompt-1', 'Watermark survives text modification');

// No watermark in plain text
assert(extract('Plain text without watermark') === null, 'No watermark in plain text');

// ─── Auth ──────────────────────────────────────────────────────────────────

console.log('\n--- Auth ---');

const token = 'my-secret-token';
const hash1 = hashToken(token);
const hash2 = hashToken(token);
assert(hash1 === hash2, 'Same token produces same hash');
assert(hash1.length === 64, 'Hash is 64 hex chars (SHA-256)');
assert(hashToken('different-token') !== hash1, 'Different tokens produce different hashes');

// ─── Summary ───────────────────────────────────────────────────────────────

console.log(`\n--- Results: ${passed} passed, ${failed} failed ---\n`);
process.exit(failed > 0 ? 1 : 0);
