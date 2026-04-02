# Prompt-Armor Server Manager
# GUI zur Steuerung von FastAPI und Prompt-Vault

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Globale Variablen für Prozesse
$script:fastapiProcess = $null
$script:vaultProcess = $null
$script:logForm = $null
$script:logTextBox = $null

# Funktion: Log-Fenster erstellen
function Create-LogWindow {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Prompt-Armor Server Logs"
    $form.Size = New-Object System.Drawing.Size(800, 600)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 11)
    
    # TextBox für Logs
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Dock = "Fill"
    $textBox.BackColor = [System.Drawing.Color]::FromArgb(17, 24, 39)
    $textBox.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
    $textBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $textBox.ReadOnly = $true
    
    $form.Controls.Add($textBox)
    
    $script:logForm = $form
    $script:logTextBox = $textBox
}

# Funktion: Log hinzufügen
function Add-Log {
    param([string]$message, [string]$color = "Green")
    
    if ($script:logTextBox -ne $null -and -not $script:logTextBox.IsDisposed) {
        $script:logTextBox.Invoke([Action]{
            $timestamp = Get-Date -Format "HH:mm:ss"
            $script:logTextBox.AppendText("[$timestamp] $message`r`n")
            $script:logTextBox.ScrollToCaret()
        })
    }
}

# Funktion: FastAPI starten
function Start-FastAPI {
    Add-Log "Starte FastAPI Server (Port 8000)..." "Yellow"
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "python"
    $psi.Arguments = "-m uvicorn main:app --host 0.0.0.0 --port 8000"
    $psi.WorkingDirectory = "C:\Users\belki\Desktop\PromptAmor"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    
    # Output Handler
    $process.OutputDataReceived += {
        if ($_.Data) { Add-Log "[FastAPI] $($_.Data)" }
    }
    $process.ErrorDataReceived += {
        if ($_.Data) { Add-Log "[FastAPI ERROR] $($_.Data)" "Red" }
    }
    
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    $script:fastapiProcess = $process
    Add-Log "✅ FastAPI gestartet (PID: $($process.Id))" "Green"
}

# Funktion: Vault starten
function Start-Vault {
    Add-Log "Starte Prompt-Vault (Port 3700)..." "Yellow"
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "node"
    $psi.Arguments = "server.js"
    $psi.WorkingDirectory = "C:\Users\belki\Desktop\PromptAmor\prompt-vault"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    
    # Output Handler
    $process.OutputDataReceived += {
        if ($_.Data) { Add-Log "[Vault] $($_.Data)" }
    }
    $process.ErrorDataReceived += {
        if ($_.Data) { Add-Log "[Vault ERROR] $($_.Data)" "Red" }
    }
    
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    $script:vaultProcess = $process
    Add-Log "✅ Vault gestartet (PID: $($process.Id))" "Green"
}

# Funktion: Server stoppen
function Stop-Servers {
    Add-Log "Beende Server..." "Yellow"
    
    if ($script:fastapiProcess -ne $null -and -not $script:fastapiProcess.HasExited) {
        Stop-Process -Id $script:fastapiProcess.Id -Force -ErrorAction SilentlyContinue
        Add-Log "🛑 FastAPI beendet" "Red"
    }
    
    if ($script:vaultProcess -ne $null -and -not $script:vaultProcess.HasExited) {
        Stop-Process -Id $script:vaultProcess.Id -Force -ErrorAction SilentlyContinue
        Add-Log "🛑 Vault beendet" "Red"
    }
    
    # Auch alle verwaisten Prozesse killen
    Get-Process -Name "python", "node" -ErrorAction SilentlyContinue | 
        Where-Object { $_.Parent.Id -eq $PID -or $_.CommandLine -like "*uvicorn*" -or $_.CommandLine -like "*server.js*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    
    $script:fastapiProcess = $null
    $script:vaultProcess = $null
}

# Funktion: Status prüfen
function Test-ServersRunning {
    $fastapiRunning = $script:fastapiProcess -ne $null -and -not $script:fastapiProcess.HasExited
    $vaultRunning = $script:vaultProcess -ne $null -and -not $script:vaultProcess.HasExited
    return ($fastapiRunning -and $vaultRunning)
}

# Haupt-GUI erstellen
$form = New-Object System.Windows.Forms.Form
$form.Text = "🛡️ Prompt-Armor Server Manager"
$form.Size = New-Object System.Drawing.Size(500, 350)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 11)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.SystemIcons]::Shield

# Titel
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "🛡️ Prompt-Armor"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(130, 20)
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
$statusPanel.BorderStyle = "None"
$form.Controls.Add($statusPanel)

# Status Labels
$fastapiStatusLabel = New-Object System.Windows.Forms.Label
$fastapiStatusLabel.Text = "❌ FastAPI (Port 8000): Offline"
$fastapiStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$fastapiStatusLabel.AutoSize = $true
$fastapiStatusLabel.Location = New-Object System.Drawing.Point(20, 15)
$statusPanel.Controls.Add($fastapiStatusLabel)

$vaultStatusLabel = New-Object System.Windows.Forms.Label
$vaultStatusLabel.Text = "❌ Vault (Port 3700): Offline"
$vaultStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
$vaultStatusLabel.AutoSize = $true
$vaultStatusLabel.Location = New-Object System.Drawing.Point(20, 45)
$statusPanel.Controls.Add($vaultStatusLabel)

# Button: Server Starten
$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "🚀 Server Starten"
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
$stopButton.Text = "🛑 Server Stoppen"
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

# Button: Logs anzeigen
$logButton = New-Object System.Windows.Forms.Button
$logButton.Text = "📋 Logs anzeigen"
$logButton.Size = New-Object System.Drawing.Size(200, 40)
$logButton.Location = New-Object System.Drawing.Point(150, 255)
$logButton.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$logButton.BackColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
$logButton.ForeColor = [System.Drawing.Color]::White
$logButton.FlatStyle = "Flat"
$logButton.FlatAppearance.BorderSize = 0
$logButton.Cursor = "Hand"
$form.Controls.Add($logButton)

# URL Labels
$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = "URLs: http://localhost:8000 | http://localhost:3700/api/health"
$urlLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$urlLabel.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
$urlLabel.AutoSize = $true
$urlLabel.Location = New-Object System.Drawing.Point(90, 305)
$form.Controls.Add($urlLabel)

# Timer für Status-Updates
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000  # 1 Sekunde

$timer.Add_Tick({
    if ($script:fastapiProcess -ne $null) {
        if (-not $script:fastapiProcess.HasExited) {
            $fastapiStatusLabel.Text = "✅ FastAPI (Port 8000): Online"
            $fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        } else {
            $fastapiStatusLabel.Text = "❌ FastAPI (Port 8000): Offline"
            $fastapiStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
        }
    }
    
    if ($script:vaultProcess -ne $null) {
        if (-not $script:vaultProcess.HasExited) {
            $vaultStatusLabel.Text = "✅ Vault (Port 3700): Online"
            $vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        } else {
            $vaultStatusLabel.Text = "❌ Vault (Port 3700): Offline"
            $vaultStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
        }
    }
    
    $running = Test-ServersRunning
    $startButton.Enabled = -not $running
    $stopButton.Enabled = $running
})

$timer.Start()

# Event Handler
$startButton.Add_Click({
    Create-LogWindow
    $script:logForm.Show()
    
    Start-FastAPI
    Start-Sleep -Seconds 2
    Start-Vault
    
    Add-Log "`r`n✨ Beide Server gestartet!" "Green"
    Add-Log "🌐 Web Interface: http://localhost:8000" "Cyan"
    Add-Log "🔐 Vault Health: http://localhost:3700/api/health" "Cyan"
    
    # URLs im Browser öffnen (optional)
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Server gestartet!`n`nWeb Interface öffnen?", 
        "Prompt-Armor", 
        "YesNo", 
        "Information"
    )
    
    if ($result -eq "Yes") {
        Start-Process "http://localhost:8000"
    }
})

$stopButton.Add_Click({
    Stop-Servers
    
    if ($script:logForm -ne $null -and -not $script:logForm.IsDisposed) {
        $script:logForm.Close()
    }
    
    [System.Windows.Forms.MessageBox]::Show(
        "Alle Server wurden beendet.", 
        "Prompt-Armor", 
        "OK", 
        "Information"
    )
})

$logButton.Add_Click({
    if ($script:logForm -eq $null -or $script:logForm.IsDisposed) {
        Create-LogWindow
    }
    $script:logForm.Show()
    $script:logForm.Focus()
})

# Form schließen = Server stoppen
$form.Add_FormClosing({
    Stop-Servers
    $timer.Stop()
})

# Anwendung starten
[System.Windows.Forms.Application]::Run($form)
