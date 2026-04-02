# 🛡️ Prompt-Armor Suite

**Komplette Prompt-Schutz-Lösung** — von einfachem Base64-Encoding bis hin zum verschlüsselten API-Proxy mit Watermarking.

---

## 🚀 Schnellstart (Windows)

```powershell
# 1. Prompt-Vault Abhängigkeiten installieren
cd prompt-vault
npm install

# 2. .env Datei erstellen (siehe unten)
copy .env.example .env
# Dann .env mit deinem Editor öffnen und ausfüllen!

# 3. Prompts verschlüsseln
npm run encrypt

# 4. BEIDE Server starten
cd ..
.\start-servers.ps1
```

**Öffne dann:**
- **Web Interface:** http://localhost:8000 (Prompt Generator)
- **Vault Health Check:** http://localhost:3700/api/health

---

## 📁 Repository-Struktur

```
PromptAmor/
│
├── 📄 main.py                    # FastAPI Backend (Port 8000)
│   ├── Speichert Prompts in PostgreSQL
│   ├── Generiert Armor-Blöcke (Base64 + SHA256)
│   └── Liefert Web-Interface unter /
│
├── 📁 static/
│   └── index.html               # Web-UI zum Erstellen & Kopieren
│
├── 📁 prompt-vault/             # NODE.JS SERVER (Port 3700)
│   ├── server.js                # API-Proxy zu Anthropic
│   ├── lib/
│   │   ├── promptManager.js     # AES-256-GCM Verschlüsselung
│   │   ├── watermark.js         # Zero-Width Unicode Watermarks
│   │   └── auth.js              # Bearer Token Auth
│   ├── prompts/
│   │   ├── raw/                 # Klartext-Prompts (.md)
│   │   └── encrypted/           # Verschlüsselte Vault-Dateien
│   └── scripts/
│       └── encryptPrompts.js    # Verschlüsselungsscript
│
├── 📁 web/                      # Astro 5 PWA (GitHub Pages)
│   └── (Wird separat deployed)
│
├── 📁 generator/
│   └── prompt-armor-generator.py  # Python CLI Tool
│
└── 📄 start-servers.ps1         # Startet beide Server gleichzeitig
```

---

## 🔧 Konfiguration

### 1. PostgreSQL Datenbank (für main.py)

```sql
CREATE DATABASE prompt_armor;

CREATE TABLE armored_prompts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    raw_prompt TEXT NOT NULL,
    armor_block TEXT NOT NULL,
    sha256_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Passwort in `main.py` anpassen (Zeile 40):**
```python
DB_CONFIG = {
    "password": "DEIN_PASSWORT",
    ...
}
```

### 2. Prompt-Vault .env

Erstelle `prompt-vault/.env`:

```env
# Geheimer Schlüssel für die Vault-Verschlüsselung (32+ Zeichen)
VAULT_SECRET=dein-sehr-langer-geheimer-schluessel-hier-12345

# Dein Anthropic API Key
ANTHROPIC_API_KEY=sk-ant-api03-...

# API Tokens für Clients (kommagetrennt)
# Erstelle mit: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
API_TOKENS=dein-token-hier,optional-zweiter-token

# Port (default: 3700)
PORT=3700

# Anthropic Model
DEFAULT_MODEL=claude-sonnet-4-20250514
MAX_TOKENS=4096
```

---

## 🎯 Zwei Schutz-Level

### Level 1: Base64 + SHA256 (main.py)

**Verwendung:** Prompt generieren → Kopieren → In KI einfügen

```javascript
// Beispiel: Prompt erstellen
POST http://localhost:8000/api/prompts
{
  "title": "SEO Artikel",
  "raw_prompt": "Schreibe einen SEO-Text über..."
}

// Response:
{
  "armor_block": "=== PROMPT-ARMOR v1.0 ===\nINTEGRITY: SHA256:..."
}
```

**Sicherheit:**
- ✅ Tamper-Evident (Hash prüft Integrität)
- ⚠️ Base64 ist kein echtes Verschlüsseln (kann dekodiert werden)
- ✅ Einfach zu nutzen

### Level 2: AES-256-GCM + API-Proxy (prompt-vault)

**Verwendung:** Prompt bleibt server-seitig, KI-Antworten werden durch Proxy geleitet

```bash
# Prompt ausführen (Prompt bleibt auf Server!)
curl -X POST http://localhost:3700/api/run \
  -H "Authorization: Bearer DEIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt_id": "seo-article",
    "variables": {"topic": "AI Security", "keyword": "prompt protection"}
  }'
```

**Sicherheit:**
- ✅ Echte AES-256-GCM Verschlüsselung
- ✅ Prompt niemals zum Client
- ✅ Zero-Width Watermarking (Nachverfolgbarkeit)
- ✅ Rate Limiting (30 req/min)
- ✅ Bearer Token Auth

---

## 📝 Prompts für Vault erstellen

1. **Datei erstellen** in `prompt-vault/prompts/raw/`:

```markdown
---
id: mein-prompt
name: Mein Prompt
author: Dein Name
copyright: (c) 2024 Dein Name
version: 1.0.0
description: Was dieser Prompt macht
---

Du bist ein Experte für {{topic}}. 
Schreibe einen Artikel über {{keyword}} mit {{word_count}} Wörtern.
```

2. **Verschlüsseln:**
```powershell
cd prompt-vault
npm run encrypt
```

3. **Server neu starten** (lād die verschlüsselten Prompts)

---

## 🖥️ Server starten

### Option A: Beide gleichzeitig (empfohlen)
```powershell
.\start-servers.ps1
```

### Option B: Einzeln
```powershell
# Terminal 1: FastAPI (Port 8000)
python -m uvicorn main:app --reload

# Terminal 2: Vault (Port 3700)
cd prompt-vault
npm start
```

---

## 🔗 API Endpunkte

### FastAPI (Port 8000)
| Methode | Endpoint | Beschreibung |
|---------|----------|--------------|
| GET | `/` | Web Interface |
| POST | `/api/prompts` | Prompt speichern & Armor generieren |
| GET | `/api/prompts` | Alle Prompts auflisten |
| GET | `/api/prompts/{id}` | Einzelnen Prompt holen |

### Prompt-Vault (Port 3700)
| Methode | Endpoint | Auth | Beschreibung |
|---------|----------|------|--------------|
| GET | `/api/health` | Nein | Health Check |
| GET | `/api/prompts` | Ja | Prompt-Metadaten |
| POST | `/api/run` | Ja | Prompt ausführen |

---

## 🧪 Testen

```powershell
# 1. Health Check
curl http://localhost:3700/api/health

# 2. Prompts auflisten
curl http://localhost:3700/api/prompts -H "Authorization: Bearer DEIN_TOKEN"

# 3. Prompt ausführen
curl -X POST http://localhost:3700/api/run `
  -H "Authorization: Bearer DEIN_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"prompt_id": "seo-article", "variables": {"topic":"Test","keyword":"demo","word_count":"100"}}'
```

---

## 📜 Lizenz

**Prompt-Armor License v1.0**

- Persönliche Nutzung: **Kostenlos**
- Kommerzielle Nutzung: Lizenz erforderlich

Kontakt: belkis.aslani@gmail.com

---

## 👤 Autor

**Belkis Aslani** — Prompt-Armor Konzept & Entwicklung
