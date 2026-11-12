@echo off
setlocal EnableExtensions DisableDelayedExpansion
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Setup-Proxmox.ps1"
exit /b %ERRORLEVEL%
