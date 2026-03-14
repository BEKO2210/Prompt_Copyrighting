# Prompt-Vault

Server-side prompt protection proxy for the Anthropic API. Prompts are encrypted at rest with AES-256-GCM and **never exposed to clients**. Every AI response is invisibly watermarked with zero-width Unicode characters for traceability.

## Architecture

```
Client  --->  Prompt-Vault  --->  Anthropic API
               |
               +-- Encrypted vault (AES-256-GCM)
               +-- Bearer token auth (SHA-256 hashed)
               +-- Zero-width watermarking
               +-- Rate limiting (30 req/min)
               +-- Legal copyright headers
```

## Security Layers

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Encryption | AES-256-GCM + scrypt | Prompts encrypted at rest |
| Auth | Bearer tokens (SHA-256) | Client authentication |
| Watermark | Zero-width Unicode | Response traceability |
| Rate Limit | express-rate-limit | Abuse prevention |
| Headers | X-Prompt-License / Copyright | Legal protection |

## Quick Start

### 1. Install

```bash
cd prompt-vault
npm install
```

### 2. Configure

```bash
cp .env.example .env
# Edit .env with your values:
#   VAULT_SECRET    - secret for encrypting the prompt vault
#   ANTHROPIC_API_KEY - your Anthropic API key
#   API_TOKENS      - comma-separated client tokens
```

Generate a secure API token:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 3. Create Prompts

Add `.md` files to `prompts/raw/` with frontmatter:

```markdown
---
id: my-prompt
name: My Prompt
author: Your Name
copyright: (c) 2024 Your Name
version: 1.0.0
description: What this prompt does
---
Your prompt content here. Use {{variable}} for dynamic values.
```

### 4. Encrypt Vault

```bash
npm run encrypt
```

### 5. Start Server

```bash
npm start
```

## API Endpoints

### `POST /api/run` (auth required)

Execute a prompt through the Anthropic API.

```bash
curl -X POST http://localhost:3700/api/run \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt_id": "seo-article",
    "variables": {
      "topic": "AI Security",
      "keyword": "prompt protection",
      "word_count": "800"
    }
  }'
```

Response:
```json
{
  "response": "...(watermarked AI response)...",
  "prompt_id": "seo-article",
  "model": "claude-sonnet-4-20250514",
  "watermarked": true,
  "usage": { "input_tokens": 150, "output_tokens": 800 }
}
```

### `GET /api/prompts` (auth required)

List available prompts (metadata only, no content).

```bash
curl http://localhost:3700/api/prompts \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### `GET /api/health` (public)

Health check endpoint.

```bash
curl http://localhost:3700/api/health
```

## Testing

```bash
npm test
```

Runs offline tests for encryption/decryption, watermarking, and auth -- no API key needed.

## Vault File Format

Binary format: `[salt:32][iv:16][tag:16][ciphertext:...]`

- **salt** (32 bytes): Random, used with scrypt for key derivation
- **iv** (16 bytes): Initialization vector for AES-256-GCM
- **tag** (16 bytes): GCM authentication tag
- **ciphertext**: AES-256-GCM encrypted JSON array of prompts

## License

Prompt-Armor License v1.0 -- Free for personal use. Commercial use requires a license.
Contact: belkis.aslani@gmail.com
