#!/usr/bin/env node

/**
 * Encrypt raw .md prompt files into the vault.
 *
 * Usage:
 *   VAULT_SECRET=my-secret node scripts/encryptPrompts.js
 *
 * Reads all .md files from prompts/raw/, parses frontmatter, and writes
 * the encrypted vault to prompts/vault.enc.
 *
 * Frontmatter format (YAML-like, between --- markers):
 *   ---
 *   id: unique-prompt-id
 *   name: Human-readable name
 *   author: Author Name
 *   copyright: (c) 2024 Author Name
 *   version: 1.0.0
 *   description: Optional description
 *   ---
 *   Prompt content goes here...
 */

import 'dotenv/config';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { encryptVault } from '../lib/promptManager.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RAW_DIR = join(__dirname, '..', 'prompts', 'raw');

const secret = process.env.VAULT_SECRET;
if (!secret) {
  console.error('Error: VAULT_SECRET environment variable is required.');
  console.error('Usage: VAULT_SECRET=my-secret node scripts/encryptPrompts.js');
  process.exit(1);
}

/**
 * Parse simple YAML-like frontmatter from a markdown file.
 */
function parseFrontmatter(raw) {
  const match = raw.match(/^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/);
  if (!match) {
    throw new Error('Missing frontmatter (--- markers)');
  }

  const meta = {};
  for (const line of match[1].split('\n')) {
    const idx = line.indexOf(':');
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const val = line.slice(idx + 1).trim();
    meta[key] = val;
  }

  return { meta, content: match[2].trim() };
}

// ─── Main ──────────────────────────────────────────────────────────────────

const files = readdirSync(RAW_DIR).filter((f) => f.endsWith('.md'));

if (files.length === 0) {
  console.error(`No .md files found in ${RAW_DIR}`);
  process.exit(1);
}

const prompts = [];

for (const file of files) {
  const raw = readFileSync(join(RAW_DIR, file), 'utf8');
  try {
    const { meta, content } = parseFrontmatter(raw);

    if (!meta.id) {
      console.warn(`  Skipping ${file}: missing "id" in frontmatter`);
      continue;
    }

    prompts.push({
      id: meta.id,
      name: meta.name || meta.id,
      author: meta.author || 'Unknown',
      copyright: meta.copyright || '',
      version: meta.version || '1.0.0',
      description: meta.description || '',
      content,
    });

    console.log(`  + ${meta.id} (${file})`);
  } catch (err) {
    console.warn(`  Skipping ${file}: ${err.message}`);
  }
}

if (prompts.length === 0) {
  console.error('No valid prompts found. Check frontmatter format.');
  process.exit(1);
}

const result = encryptVault(prompts, secret);
console.log(`\nVault encrypted: ${result.count} prompt(s) -> ${result.path}`);
