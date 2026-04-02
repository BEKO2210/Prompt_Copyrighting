# Prompt-Armor Server Manager
# GUI zur Steuerung von FastAPI und Prompt-Vault

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Globale Variablen
$script:fastapiProcess = $null
$script:vaultProcess = $null

# Funktion: Server stoppen
function Stop-Servers {
    if ($script:fastapiProcess -ne $null -and -not $script:fastapiProcess.HasExited) {
        Stop-Process -Id $script:fastapiProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    if ($script:vaultProcess -ne $null -and -not $script:vaultProcess.HasExited) {
        Stop-Process -Id $script:vaultProcess.Id -Force -ErrorAction SilentlyContinue
    }
    
    # Auch alle verwaisten Prozesse killen
    Get-Process -Name "python", "node" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*uvicorn*" -or $_.CommandLine -like "*server.js*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    
    $script:fastapiProcess = $null
    $script:vaultProcess = $null
}

# Haupt-GUI erstellen
$form = New-Object System.Windows.Forms.Form
$form.Text = "Prompt-Armor Server Manager"
$form.Size = New-Object System.Drawing.Size(500, 320)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 11)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Shield

# Titel
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Prompt-Armor"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(160, 20)
$form.Controls.Add($titleLabel)

# Untertitel
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Server Control Panel"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
$subtitleLabel.AutoSize = $true
$subtitleLabel.Location = New-Object System.Drawing.Point(175, 55)
$form.Controls.Add($subtitleLabel)

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(460, 80)
$statusPanel.Location = New-Object System.Drawing.Point(20, 90)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 30)
$form.Controls.Add($statusPanel)

# Status Labels
$fastapiStatusLabel = New-Object System.Windows.Forms.Label
$fastapiStatusLabel.Text = "[OFF] FastAPI (Port 8000): Offline"
$fastapiStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$fastapiStatusLabel.AutoSize = $true
$fastapiStatusLabel.Location = New-Object System.Drawing.Point(20, 15)
$statusPanel.Controls.Add($fastapiStatusLabel)

$vaultStatusLabel = New-Object System.Windows.Forms.Label
$vaultStatusLabel.Text = "[OFF] Vault (Port 3700): Offline"
$vaultStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$vaultStatusLabel.AutoSize = $true
$vaultStatusLabel.Location = New-Object System.Drawing.Point(20, 45)
$statusPanel.Controls.Add($vaultStatusLabel)

# Button: Server Starten
$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Server Starten"
$startButton.Size = New-Object System.Drawing.Size(200, 50)
$startButton.Location = New-Object System.Drawing.Point(40, 190)
$startButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$startButton.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.FlatStyle = "Flat"
$startButton.FlatAppearance.BorderSize = 0
$startButton.Cursor = "Hand"
$form.Controls.Add($startButton)

# Button: Server Stoppen
$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "Server Stoppen"
$stopButton.Size = New-Object System.Drawing.Size(200, 50)
$stopButton.Location = New-Object System.Drawing.Point(260, 190)
$stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$stopButton.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$stopButton.ForeColor = [System.Drawing.Color]::White
$stopButton.FlatStyle = "Flat"
$stopButton.FlatAppearance.BorderSize = 0
$stopButton.Cursor = "Hand"
$stopButton.Enabled = $false
$form.Controls.Add($stopButton)

# URL Labels
$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = "localhost:8000 | localhost:3700/api/health"
$urlLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$urlLabel.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
$urlLabel.AutoSize = $true
$urlLabel.Location = New-Object System.Drawing.Point(120, 260)
$form.Controls.Add($urlLabel)

# Timer fuer Status-Updates
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500

$timer.Add_Tick({
    # FastAPI Status
    if ($script:fastapiProcess -ne $null) {
        try {
            $null = Get-Process -Id $script:fastapiProcess.Id -ErrorAction Stop
            $fastapiStatusLabel.Text = "[ON] FastAPI (Port 8000): Online"
            $fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        } catch {
            $fastapiStatusLabel.Text = "[OFF] FastAPI (Port 8000): Offline"
            $fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
            $script:fastapiProcess = $null
        }
    } else {
        $fastapiStatusLabel.Text = "[OFF] FastAPI (Port 8000): Offline"
        $fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
    }
    
    # Vault Status
    if ($script:vaultProcess -ne $null) {
        try {
            $null = Get-Process -Id $script:vaultProcess.Id -ErrorAction Stop
            $vaultStatusLabel.Text = "[ON] Vault (Port 3700): Online"
            $vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        } catch {
            $vaultStatusLabel.Text = "[OFF] Vault (Port 3700): Offline"
            $vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
            $script:vaultProcess = $null
        }
    } else {
        $vaultStatusLabel.Text = "[OFF] Vault (Port 3700): Offline"
        $vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
    }
    
    # Buttons aktualisieren
    $running = ($script:fastapiProcess -ne $null -or $script:vaultProcess -ne $null)
    $startButton.Enabled = -not $running
    $stopButton.Enabled = $running
})

$timer.Start()

# Event Handler: Start
$startButton.Add_Click({
    $baseDir = "C:\Users\belki\Desktop\PromptAmor"
    
    # FastAPI starten (eigenes Fenster)
    $cmd1 = "cd `"$baseDir`" ; python -m uvicorn main:app --host 0.0.0.0 --port 8000"
    $script:fastapiProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd1 -PassThru
    
    Start-Sleep -Seconds 2
    
    # Vault starten (eigenes Fenster)
    $cmd2 = "cd `"$baseDir\prompt-vault`" ; npm start"
    $script:vaultProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd2 -PassThru
    
    Start-Sleep -Seconds 3
    
    # Frage ob Browser oeffnen
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Server werden gestartet!`n`nWeb Interface im Browser oeffnen?", 
        "Prompt-Armor", 
        "YesNo", 
        "Information"
    )
    
    if ($result -eq "Yes") {
        Start-Process "http://localhost:8000"
    }
})

# Event Handler: Stop
$stopButton.Add_Click({
    Stop-Servers
    
    [System.Windows.Forms.MessageBox]::Show(
        "Alle Server wurden beendet.", 
        "Prompt-Armor", 
        "OK", 
        "Information"
    )
})

# Form schliessen = Server stoppen
$form.Add_FormClosing({
    Stop-Servers
    $timer.Stop()
})

# Anwendung starten
[System.Windows.Forms.Application]::Run($form)
