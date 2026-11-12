@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0" || exit /b 1
title Proxmox Launcher - Local / Tailscale VPN

rem Load the local, gitignored configuration from the script directory.
set "CONFIG_FILE=%~dp0proxmox.local.cmd"
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Missing local configuration: "%CONFIG_FILE%"
    echo Copy proxmox.local.example.cmd to proxmox.local.cmd and edit your values.
    goto fail
)
call "%CONFIG_FILE%"
if errorlevel 1 (
    echo [ERROR] Cannot load local configuration.
    goto fail
)

set "LOCAL_SCRIPT=%~dp0Wake-Proxmox.ps1"
set "REMOTE_SCRIPT=%~dp0Wake-Proxmox-VPN.ps1"

rem Defaults shared by both modes; values may be overridden by the local config.
if not defined TARGET_PORT set "TARGET_PORT=8006"
if not defined VPN_ESP32_PORT set "VPN_ESP32_PORT=9999"
if not defined VPN_ESP32_HOSTNAME set "VPN_ESP32_HOSTNAME=esp32-pve-wol"
if not defined MAX_PING_ATTEMPTS set "MAX_PING_ATTEMPTS=5"
if not defined MAX_CHECK_ATTEMPTS set "MAX_CHECK_ATTEMPTS=18"
if not defined CHECK_INTERVAL_SECONDS set "CHECK_INTERVAL_SECONDS=5"

:menu
echo.
echo ==========================================
echo          PROXMOX POWER LAUNCHER
echo ==========================================
echo [L] Local  - home network (Magic Packet)
echo [R] Remote - Tailscale VPN via ESP32
echo [Q] Quit
echo.
choice /C LRQ /N /M "Choose connection [L/R/Q]: "
if errorlevel 3 goto quit
if errorlevel 2 goto remote
if errorlevel 1 goto local
goto quit

:local
if not exist "%LOCAL_SCRIPT%" (
    echo [ERROR] Missing file: "%LOCAL_SCRIPT%"
    goto fail
)
if not defined PVE_MAC goto missinglocal
if not defined LAN_BROADCAST goto missinglocal
if not defined LAN_PVE_IP goto missinglocal
if /I "%PVE_MAC%"=="REPLACE_ME" goto missinglocal
if /I "%LAN_PVE_IP%"=="REPLACE_ME" goto missinglocal
if /I "%LAN_BROADCAST%"=="REPLACE_ME" goto missinglocal

echo [INFO] Starting local Wake-on-LAN...
if defined LAN_SOURCE_IP (
    powershell.exe -NoLogo -NoProfile -File "%LOCAL_SCRIPT%" -MacAddress "%PVE_MAC%" -BroadcastAddress "%LAN_BROADCAST%" -SourceIPAddress "%LAN_SOURCE_IP%" -TargetIPAddress "%LAN_PVE_IP%" -TargetPort "%TARGET_PORT%" -OpenBrowser -MaxAttempts "%MAX_CHECK_ATTEMPTS%" -IntervalSeconds "%CHECK_INTERVAL_SECONDS%"
) else (
    powershell.exe -NoLogo -NoProfile -File "%LOCAL_SCRIPT%" -MacAddress "%PVE_MAC%" -BroadcastAddress "%LAN_BROADCAST%" -TargetIPAddress "%LAN_PVE_IP%" -TargetPort "%TARGET_PORT%" -OpenBrowser -MaxAttempts "%MAX_CHECK_ATTEMPTS%" -IntervalSeconds "%CHECK_INTERVAL_SECONDS%"
)
set "RESULT=%ERRORLEVEL%"
goto result

:remote
if not exist "%REMOTE_SCRIPT%" (
    echo [ERROR] Missing file: "%REMOTE_SCRIPT%"
    goto fail
)
if not defined VPN_ESP32_IP goto missingremote
if not defined VPN_PVE_IP goto missingremote
if /I "%VPN_ESP32_IP%"=="REPLACE_ME" goto missingremote
if /I "%VPN_PVE_IP%"=="REPLACE_ME" goto missingremote

echo [INFO] Starting remote wake via Tailscale and ESP32...
if "%MAX_PING_ATTEMPTS%"=="0" (
    echo [INFO] MAX_PING_ATTEMPTS is 0. Bypassing ESP32 ping test...
    powershell.exe -NoLogo -NoProfile -File "%REMOTE_SCRIPT%" -Esp32IP "%VPN_ESP32_IP%" -Esp32HostName "%VPN_ESP32_HOSTNAME%" -Esp32Port "%VPN_ESP32_PORT%" -TargetIPAddress "%VPN_PVE_IP%" -TargetPort "%TARGET_PORT%" -OpenBrowser -MaxPingAttempts 0 -MaxAttempts "%MAX_CHECK_ATTEMPTS%" -IntervalSeconds "%CHECK_INTERVAL_SECONDS%"
) else (
    powershell.exe -NoLogo -NoProfile -File "%REMOTE_SCRIPT%" -Esp32IP "%VPN_ESP32_IP%" -Esp32HostName "%VPN_ESP32_HOSTNAME%" -Esp32Port "%VPN_ESP32_PORT%" -TargetIPAddress "%VPN_PVE_IP%" -TargetPort "%TARGET_PORT%" -OpenBrowser -MaxPingAttempts "%MAX_PING_ATTEMPTS%" -MaxAttempts "%MAX_CHECK_ATTEMPTS%" -IntervalSeconds "%CHECK_INTERVAL_SECONDS%"
)
set "RESULT=%ERRORLEVEL%"
goto result

:missinglocal
echo [ERROR] Add PVE_MAC, LAN_BROADCAST and LAN_PVE_IP to proxmox.local.cmd.
goto fail

:missingremote
echo [ERROR] Add VPN_ESP32_IP and VPN_PVE_IP to proxmox.local.cmd.
goto fail

:result
if "%RESULT%"=="0" (
    echo.
    echo [OK] Proxmox TCP service is reachable; the browser should open.
    exit /b 0
)
echo.
echo [ERROR] Launcher exited with code %RESULT%.
echo Read the diagnostics above; remote power-on was not confirmed.
pause
exit /b %RESULT%

:fail
pause
exit /b 1

:quit
exit /b 0
