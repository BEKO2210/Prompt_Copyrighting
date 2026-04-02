# Prompt-Armor Server Starter
# Startet beide Server: FastAPI (Port 8000) und Prompt-Vault (Port 3700)

$Host.UI.RawUI.WindowTitle = "Prompt-Armor Servers"

Write-Host "🛡️  Prompt-Armor Server Starter" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Prüfe ob .env existiert
if (-not (Test-Path "prompt-vault\.env")) {
    Write-Host "⚠️  WARNUNG: prompt-vault\.env nicht gefunden!" -ForegroundColor Yellow
    Write-Host "    Bitte kopiere .env.example nach .env und fülle die Werte aus." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    cd prompt-vault" -ForegroundColor DarkGray
    Write-Host "    copy .env.example .env" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "Drücke Enter zum Beenden"
    exit 1
}

# Prüfe ob node_modules existiert
if (-not (Test-Path "prompt-vault\node_modules")) {
    Write-Host "📦 Installiere Prompt-Vault Abhängigkeiten..." -ForegroundColor Yellow
    Set-Location prompt-vault
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ npm install fehlgeschlagen!" -ForegroundColor Red
        Read-Host "Drücke Enter zum Beenden"
        exit 1
    }
    Set-Location ..
}

Write-Host "🚀 Starte Server..." -ForegroundColor Green
Write-Host ""

# Starte Prompt-Vault in neuem Fenster
Write-Host "🔐 Prompt-Vault (Node.js) auf Port 3700..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$PSScriptRoot\prompt-vault'; `$Host.UI.RawUI.WindowTitle='Prompt-Vault (Port 3700)'; npm start"
)

# Kurze Pause damit Vault nicht die Konsole übernimmt
Start-Sleep -Seconds 2

# Starte FastAPI im aktuellen Fenster
Write-Host "🌐 FastAPI (Python) auf Port 8000..." -ForegroundColor Cyan
Write-Host ""

Write-Host "================================" -ForegroundColor Green
Write-Host "✅ Beide Server werden gestartet!" -ForegroundColor Green
Write-Host ""
Write-Host "📍 URLs:" -ForegroundColor White
Write-Host "   Web Interface:  http://localhost:8000" -ForegroundColor Yellow
Write-Host "   Vault Health:   http://localhost:3700/api/health" -ForegroundColor Yellow
Write-Host "   API Docs:       http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  Zum Beenden: Strg+C drücken" -ForegroundColor Magenta
Write-Host ""
Write-Host "================================" -ForegroundColor Green

# Starte FastAPI (blockierend, damit Fenster offen bleibt)
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

Write-Host ""
Write-Host "👋 Server gestoppt." -ForegroundColor Cyan
