import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const VAULT_PATH = join(__dirname, '..', 'prompts', 'vault.enc');
const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32;
const IV_LENGTH = 16;
const TAG_LENGTH = 16;
const SALT_LENGTH = 32;

/**
 * Derive a 256-bit key from the vault secret using scrypt.
 */
function deriveKey(secret, salt) {
  return scryptSync(secret, salt, KEY_LENGTH);
}

/**
 * Encrypt a JSON-serializable object and write to vault file.
 * Format: [salt:32][iv:16][tag:16][ciphertext:...]
 */
export function encryptVault(prompts, secret, outputPath = VAULT_PATH) {
  const salt = randomBytes(SALT_LENGTH);
  const key = deriveKey(secret, salt);
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);

  const plaintext = JSON.stringify(prompts);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  const payload = Buffer.concat([salt, iv, tag, encrypted]);
  writeFileSync(outputPath, payload);

  return { count: prompts.length, path: outputPath };
}

/**
 * Decrypt the vault file and return prompts as an array.
 * Prompts are held in memory only -- never written back to disk.
 */
export function decryptVault(secret, vaultPath = VAULT_PATH) {
  if (!existsSync(vaultPath)) {
    throw new Error('Vault file not found. Run "npm run encrypt" first.');
  }

  const payload = readFileSync(vaultPath);

  const salt = payload.subarray(0, SALT_LENGTH);
  const iv = payload.subarray(SALT_LENGTH, SALT_LENGTH + IV_LENGTH);
  const tag = payload.subarray(SALT_LENGTH + IV_LENGTH, SALT_LENGTH + IV_LENGTH + TAG_LENGTH);
  const ciphertext = payload.subarray(SALT_LENGTH + IV_LENGTH + TAG_LENGTH);

  const key = deriveKey(secret, salt);
  const decipher = createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(tag);

  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return JSON.parse(decrypted.toString('utf8'));
}

/**
 * In-memory prompt store. Loaded once at startup, never persisted.
 */
export class PromptVault {
  #prompts = new Map();

  constructor(secret) {
    const list = decryptVault(secret);
    for (const prompt of list) {
      this.#prompts.set(prompt.id, prompt);
    }
  }

  /** Get prompt content by ID. Returns the full prompt object or null. */
  get(id) {
    return this.#prompts.get(id) ?? null;
  }

  /** List all prompts -- metadata only, NO content exposed. */
  list() {
    return Array.from(this.#prompts.values()).map((p) => ({
      id: p.id,
      name: p.name,
      author: p.author,
      copyright: p.copyright,
      version: p.version,
      description: p.description ?? '',
    }));
  }

  /** Number of loaded prompts. */
  get count() {
    return this.#prompts.size;
  }
}
