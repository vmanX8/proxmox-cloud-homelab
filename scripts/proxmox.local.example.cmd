@echo off
rem Examples only. Use Setup-Proxmox.cmd to create local settings.
rem TEST-NET addresses are non-routable demonstration values.
set "LAN_MAC=AA:BB:CC:DD:EE:FF"
set "LAN_BROADCAST=192.0.2.255"
set "PROXMOX_LAN_IP=192.0.2.10"
set "ESP32_TS_IP=198.51.100.20"
set "PROXMOX_TS_IP=198.51.100.10"
set "WAKE_UDP_PORT=9999"
set "TARGET_TCP_PORT=8006"
rem DERP-only gateway default: skip unreliable DISCO preflight; 1..20 enables strict checks.
set "MAX_PING_ATTEMPTS=0"
set "TCP_ATTEMPTS=18"
set "TCP_INTERVAL=5"
