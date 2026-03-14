import 'dotenv/config';
import express from 'express';
import rateLimit from 'express-rate-limit';
import Anthropic from '@anthropic-ai/sdk';
import { PromptVault } from './lib/promptManager.js';
import { embed } from './lib/watermark.js';
import { bearerAuth, hashToken, requestLogger } from './lib/auth.js';

// ─── Config ────────────────────────────────────────────────────────────────

const PORT = parseInt(process.env.PORT || '3700', 10);
const VAULT_SECRET = process.env.VAULT_SECRET;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const API_TOKENS = (process.env.API_TOKENS || '').split(',').filter(Boolean);
const DEFAULT_MODEL = process.env.DEFAULT_MODEL || 'claude-sonnet-4-20250514';
const MAX_TOKENS = parseInt(process.env.MAX_TOKENS || '4096', 10);

// ─── Validate required env vars ────────────────────────────────────────────

if (!VAULT_SECRET) {
  console.error('VAULT_SECRET is required. Set it in .env');
  process.exit(1);
}
if (!ANTHROPIC_API_KEY) {
  console.error('ANTHROPIC_API_KEY is required. Set it in .env');
  process.exit(1);
}
if (API_TOKENS.length === 0) {
  console.error('API_TOKENS is required. Provide at least one comma-separated token in .env');
  process.exit(1);
}

// ─── Init ──────────────────────────────────────────────────────────────────

const vault = new PromptVault(VAULT_SECRET);
console.log(`Vault loaded: ${vault.count} prompt(s)`);

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });
const allowedHashes = new Set(API_TOKENS.map(hashToken));

const app = express();
app.use(express.json({ limit: '100kb' }));
app.use(requestLogger);

// ─── Legal / copyright headers on every response ──────────────────────────

app.use((req, res, next) => {
  res.set({
    'X-Prompt-License': 'Prompt-Armor Commercial License v1.0',
    'X-Prompt-Copyright': '(c) Belkis Aslani -- All rights reserved',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Cache-Control': 'no-store',
  });
  next();
});

// ─── Rate limiter ──────────────────────────────────────────────────────────

const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30,             // 30 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Rate limit exceeded. Try again later.' },
});

app.use('/api/', limiter);

// ─── Auth for protected routes ─────────────────────────────────────────────

app.use('/api/run', bearerAuth(allowedHashes));
app.use('/api/prompts', bearerAuth(allowedHashes));

// ─── Routes ────────────────────────────────────────────────────────────────

/**
 * POST /api/run
 * Execute a prompt through the Anthropic API.
 *
 * Body: { prompt_id: string, variables?: Record<string, string>, model?: string }
 * Response: { response: string, prompt_id: string, model: string, watermarked: true }
 *
 * The raw prompt content is NEVER returned to the client.
 */
app.post('/api/run', async (req, res) => {
  try {
    const { prompt_id, variables = {}, model } = req.body;

    if (!prompt_id) {
      return res.status(400).json({ error: 'prompt_id is required.' });
    }

    const prompt = vault.get(prompt_id);
    if (!prompt) {
      return res.status(404).json({ error: `Prompt "${prompt_id}" not found.` });
    }

    // Interpolate variables into prompt content: {{var_name}} → value
    let content = prompt.content;
    for (const [key, value] of Object.entries(variables)) {
      content = content.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), String(value));
    }

    // Call Anthropic API
    const useModel = model || DEFAULT_MODEL;
    const message = await anthropic.messages.create({
      model: useModel,
      max_tokens: MAX_TOKENS,
      messages: [{ role: 'user', content }],
    });

    // Extract text response
    const textBlock = message.content.find((b) => b.type === 'text');
    const rawResponse = textBlock?.text || '';

    // Watermark the response
    const watermarked = embed(rawResponse, prompt_id, {
      token: req.tokenHash?.slice(0, 8),
    });

    res.json({
      response: watermarked,
      prompt_id,
      model: useModel,
      watermarked: true,
      usage: message.usage,
    });
  } catch (err) {
    console.error('POST /api/run error:', err.message);

    if (err.status === 401 || err.status === 403) {
      return res.status(502).json({ error: 'Anthropic API authentication failed.' });
    }
    if (err.status === 429) {
      return res.status(429).json({ error: 'Anthropic API rate limit. Try again later.' });
    }

    res.status(500).json({ error: 'Internal server error.' });
  }
});

/**
 * GET /api/prompts
 * List all available prompts (metadata only, NO content).
 */
app.get('/api/prompts', (req, res) => {
  res.json({ prompts: vault.list() });
});

/**
 * GET /api/health
 * Public health check (no auth required).
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    prompts_loaded: vault.count,
    uptime: Math.floor(process.uptime()),
  });
});

// ─── 404 fallback ──────────────────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({ error: 'Not found.' });
});

// ─── Start ─────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Prompt-Vault server running on http://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
});
