@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "DIR=%~dp0"
set "CFG=%DIR%proxmox.local.cmd"

if not exist "%CFG%" (
    echo No local settings found.
    call "%DIR%Setup-Proxmox.cmd"
    if errorlevel 1 exit /b 2
)
call "%CFG%"

:menu
echo.
echo ===== Proxmox Wake Launcher =====
echo 1. Local LAN Wake-on-LAN
echo 2. Remote Wake via Tailscale / ESP32
echo 3. Configure
echo 4. Quit
choice /C 1234 /N /M "Select [1-4]: "
if errorlevel 4 goto done
if errorlevel 3 goto setup
if errorlevel 2 goto remote
if errorlevel 1 goto local
goto done

:local
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DIR%Wake-Proxmox.ps1" -MacAddress "%LAN_MAC%" -BroadcastAddress "%LAN_BROADCAST%" -TargetIPAddress "%PROXMOX_LAN_IP%" -TargetPort %TARGET_TCP_PORT% -MaxAttempts %TCP_ATTEMPTS% -IntervalSeconds %TCP_INTERVAL% -OpenBrowser
set "RESULT=%ERRORLEVEL%"
echo LAN exit code: %RESULT%
pause
goto menu

:remote
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%DIR%Wake-Proxmox-VPN.ps1" -Esp32IPAddress "%ESP32_TS_IP%" -TargetIPAddress "%PROXMOX_TS_IP%" -UdpPort %WAKE_UDP_PORT% -TargetPort %TARGET_TCP_PORT% -MaxAttempts %TCP_ATTEMPTS% -IntervalSeconds %TCP_INTERVAL% -OpenBrowser
set "RESULT=%ERRORLEVEL%"
echo Remote exit code: %RESULT%
pause
goto menu

:setup
call "%DIR%Setup-Proxmox.cmd"
if errorlevel 1 (
    echo Configuration not updated.
    pause
    goto menu
)
call "%CFG%"
goto menu

:done
exit /b 0
