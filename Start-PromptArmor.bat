@echo off
title Prompt-Armor Server Manager
cd /d "C:\Users\belki\Desktop\PromptAmor"
echo 🛡️  Prompt-Armor Server Manager wird gestartet...
echo.
powershell -ExecutionPolicy Bypass -File "PromptArmor-Manager.ps1"
pause
