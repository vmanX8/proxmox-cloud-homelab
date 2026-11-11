# Homelab Architecture Overview

> **Scope:** Observed single-host homelab and experimental remote wake, not a production cloud deployment.

## Components and responsibilities

| Component | Purpose | Validation boundary |
|---|---|---|
| Toshiba Satellite C75-A / Proxmox VE | Single physical virtualization host and Web UI | Host, kernel/KVM device and LAN UI verified |
| Ethernet `nic0`, Linux bridge `vmbr0` | Physical LAN connection and bridge for management/future guests | Bridge connectivity and recovery verified |
| Modified `alx-wol` DKMS module | Allow AR8162 Ethernet NIC to react to LAN Magic Packets | Wake from complete shutdown verified |
| Windows PowerShell WoL utility | Local LAN packet sender and optional TCP availability polling | Success, negative, regression and launcher tests |
| Proxmox Tailscale configuration | Authenticated private remote administration while the host is running | Web UI login and dashboard verified from an external tablet and an authorized Windows laptop; [Lab 03](03-tailscale-vpn-remote-access.md) |
| ESP32-WROOM-32D gateway | Independently powered Tailscale-to-LAN wake bridge | Two end-to-end wakes with DERP observed; security work remains |

## Management network (when the host is powered on)

```text
Client -- private Tailscale connection --> powered-on Proxmox
                                           management interface
```

Authenticated external management access and gateway-assisted wake-to-service validation are detailed in [Lab 03](03-tailscale-vpn-remote-access.md). The Proxmox host cannot receive its own VPN traffic when physically shut down.

## Local or remote power-on

```text
LAN Windows PC -- UDP broadcast --> Ethernet NIC --> Proxmox boot

Remote Tailscale client --> ESP32 gateway (DERP path observed)
                         --> LAN UDP Magic Packet
                         --> Ethernet NIC --> Proxmox boot
```

The ESP32 firmware is **not duplicated** here. See [ESP32-WoL](https://github.com/vmanX8/ESP32-WoL), including [validation and limitations](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md) and [attribution](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/UPSTREAM_ATTRIBUTION.md).

## Trust and failure boundaries

- Tailscale configuration and remote wake command authorization must be reviewed separately.
- On the tested ESP32 adaptation, **DERP TLS certificate verification is disabled** in the reviewed source. Treat as a security blocker.
- No evidence here proves HA, failover, endurance, production hardening or running VM workloads.
- Personal IP addresses, tailnet information, MAC addresses, keys and device identities are intentionally omitted.

## Lab index

01 [Proxmox installation](01-proxmox-installation.md) ·
02 [Linux networking](02-linux-networking.md) ·
03 [Tailscale remote access](03-tailscale-vpn-remote-access.md) ·
04 [Wake-on-LAN/DKMS](04-wake-on-lan-alx-dkms.md) ·
05 [PowerShell utility](05-powershell-wol-automation.md) ·
06 [ESP32 gateway](06-esp32-remote-wol-gateway.md)
