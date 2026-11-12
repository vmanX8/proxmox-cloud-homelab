@echo off
rem COPY this file to proxmox.local.cmd, then replace all REPLACE_ME values.
rem Do NOT commit proxmox.local.cmd: it contains your real network information.
rem The file is loaded with CALL. Only use your own trusted local config.

rem -- Proxmox on the home LAN --
set "PVE_MAC=REPLACE_ME"
set "LAN_BROADCAST=REPLACE_ME"
set "LAN_PVE_IP=REPLACE_ME"
rem Optional: select the Windows LAN adapter explicitly if needed.
set "LAN_SOURCE_IP="

rem -- Tailscale private addresses --
set "VPN_ESP32_IP=REPLACE_ME"
set "VPN_PVE_IP=REPLACE_ME"
set "VPN_ESP32_HOSTNAME=esp32-pve-wol"

rem -- Ports and retry policy --
set "TARGET_PORT=8006"
set "VPN_ESP32_PORT=9999"
set "MAX_PING_ATTEMPTS=5"
set "MAX_CHECK_ATTEMPTS=18"
set "CHECK_INTERVAL_SECONDS=5"
