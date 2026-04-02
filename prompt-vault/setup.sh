#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Prompt-Vault Server Setup Script
# Richtet den Prompt-Vault API Server auf einem Linux Server ein
# ═══════════════════════════════════════════════════════════
set -e

echo "═══════════════════════════════════════════════════════"
echo " Prompt-Vault Server Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

# ─── 1. Node.js prüfen / installieren ─────────────────────
echo "[1/6] Checking Node.js..."
if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v)
    echo "  ✓ Node.js $NODE_VERSION found"
else
    echo "  Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    echo "  ✓ Node.js $(node -v) installed"
fi

# ─── 2. Dependencies installieren ─────────────────────────
echo ""
echo "[2/6] Installing dependencies..."
cd "$(dirname "$0")"
npm install --production
echo "  ✓ Dependencies installed"

# ─── 3. .env erstellen ────────────────────────────────────
echo ""
echo "[3/6] Configuring environment..."
if [ -f .env ]; then
    echo "  .env already exists — skipping"
else
    # Generate secure secrets
    VAULT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
    API_TOKEN=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

    cat > .env << ENVEOF
# Prompt-Vault Configuration (auto-generated)

# Secret for encrypting/decrypting the vault
VAULT_SECRET=${VAULT_SECRET}

# Your Anthropic API key (FILL THIS IN!)
ANTHROPIC_API_KEY=sk-ant-api03-REPLACE-ME

# API token for client authentication
API_TOKENS=${API_TOKEN}

# Server port
PORT=3700

# Default model
DEFAULT_MODEL=claude-sonnet-4-20250514

# Max tokens per response
MAX_TOKENS=4096
ENVEOF

    echo "  ✓ .env created with auto-generated secrets"
    echo ""
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║  IMPORTANT: Edit .env and add your Anthropic    ║"
    echo "  ║  API key before starting the server!            ║"
    echo "  ║                                                  ║"
    echo "  ║  nano .env                                       ║"
    echo "  ║                                                  ║"
    echo "  ║  Your API token for clients:                     ║"
    echo "  ║  ${API_TOKEN}  ║"
    echo "  ╚══════════════════════════════════════════════════╝"
fi

# ─── 4. Vault verschlüsseln ───────────────────────────────
echo ""
echo "[4/6] Encrypting prompt vault..."
if [ -f prompts/vault.enc ]; then
    echo "  vault.enc already exists — skipping"
    echo "  (To re-encrypt: npm run encrypt)"
else
    if [ -d prompts/raw ] && ls prompts/raw/*.md &>/dev/null 2>&1; then
        npm run encrypt
        echo "  ✓ Vault encrypted"
    else
        echo "  No prompts in prompts/raw/ — skipping"
        echo "  Add .md files to prompts/raw/ then run: npm run encrypt"
    fi
fi

# ─── 5. Systemd Service erstellen ─────────────────────────
echo ""
echo "[5/6] Creating systemd service..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

sudo tee /etc/systemd/system/prompt-vault.service > /dev/null << SERVICEEOF
[Unit]
Description=Prompt-Vault API Server
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=${SCRIPT_DIR}
ExecStart=$(which node) server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo systemctl daemon-reload
sudo systemctl enable prompt-vault
echo "  ✓ Systemd service created and enabled"

# ─── 6. Firewall (optional) ───────────────────────────────
echo ""
echo "[6/6] Firewall check..."
if command -v ufw &>/dev/null; then
    PORT=$(grep "^PORT=" .env 2>/dev/null | cut -d= -f2 || echo "3700")
    echo "  To allow external access: sudo ufw allow ${PORT}/tcp"
else
    echo "  ufw not found — configure firewall manually if needed"
fi

# ─── Done ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo " Setup complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo " Next steps:"
echo "   1. Edit .env and add your ANTHROPIC_API_KEY:"
echo "      nano ${SCRIPT_DIR}/.env"
echo ""
echo "   2. Add prompts to prompts/raw/ and encrypt:"
echo "      npm run encrypt"
echo ""
echo "   3. Start the server:"
echo "      sudo systemctl start prompt-vault"
echo ""
echo "   4. Check status:"
echo "      sudo systemctl status prompt-vault"
echo "      curl http://localhost:3700/api/health"
echo ""
echo "   5. View logs:"
echo "      journalctl -u prompt-vault -f"
echo ""
echo " API usage:"
echo "   curl -X POST http://localhost:3700/api/run \\"
echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"prompt_id\": \"code-review\", \"variables\": {\"language\": \"Python\", \"code\": \"...\"}}'""
echo ""
