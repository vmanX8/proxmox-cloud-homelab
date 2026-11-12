# Proxmox Cloud Homelab

A personal homelab built with Proxmox VE to explore virtualization, Linux networking, cloud infrastructure, containers, and remote system administration through hands-on experiments.

## Project Overview

This project documents my practical learning journey in building and managing a self-hosted virtualization environment using repurposed hardware.

The goal is to develop a better understanding of infrastructure components, system administration, troubleshooting, and the technologies underlying modern cloud platforms.

Rather than following tutorials without understanding the underlying concepts, I aim to document the technical decisions, problems, solutions, and lessons learned from each experiment.

## Hardware & Software

| Component | Configuration |
|---|---|
| Host machine | Toshiba Satellite C75-A |
| Hypervisor | Proxmox VE 9.2.2 |
| Operating system | Debian-based Proxmox VE |
| Kernel (initial setup) | 7.0.2-6-pve |
| Network adapter | Qualcomm Atheros AR8162 |
| Network configuration | Linux bridge (`vmbr0`) |
| Remote power management | Wake-on-LAN |

## Completed Work

- Installed and configured Proxmox VE on a repurposed laptop.
- Configured Ethernet networking and a Linux bridge.
- Configured the laptop for headless operation with the lid closed.
- Investigated missing Wake-on-LAN support in the original Linux `alx` driver.
- Installed and tested the community-maintained `alx-wol` driver through DKMS.
- Diagnosed and recovered network connectivity after a driver reload.
- Successfully verified Wake-on-LAN from a full shutdown using a Magic Packet from a Windows PC.
- Validated authenticated Proxmox remote management through Tailscale from outside the LAN.
- Tested ESP32-assisted remote wake and service-reachability monitoring; security and endurance verification remain open.


## Labs & Documentation

[Architecture overview](docs/ARCHITECTURE.md) — host access, LAN WoL and the separately maintained ESP32 gateway.

This homelab is documented through a series of hands-on labs covering infrastructure setup, Linux networking, troubleshooting, and automation.

Each lab documents the technical decisions, implementation steps, challenges encountered, and lessons learned.

| Lab | Topic | Documentation |
|---|---|---|
| 01 | Proxmox VE Installation & Host Verification | [View Lab 01](docs/01-proxmox-installation.md) |
| 02 | Linux Networking & Bridge Configuration | [View Lab 02](docs/02-linux-networking.md) |
| 03 | Tailscale VPN & Remote Access | [View Lab 03](docs/03-tailscale-vpn-remote-access.md) |
| 04 | Wake-on-LAN & `alx-wol` DKMS Driver | [View Lab 04](docs/04-wake-on-lan-alx-dkms.md) |
| 05 | PowerShell Wake-on-LAN Automation | [View Lab 05](docs/05-powershell-wol-automation.md) |
| 06 | ESP32 Remote Wake-on-LAN Gateway | [View Lab 06](docs/06-esp32-remote-wol-gateway.md) |

### Featured Case Study — Wake-on-LAN & Driver Troubleshooting

**Challenge:** The Toshiba Satellite C75-A's Qualcomm Atheros AR8162 Ethernet adapter did not expose Wake-on-LAN capabilities through the default Linux `alx` driver.

**Approach:** Integrated the community-maintained [`alx-wol`](https://github.com/AndiWeiss/alx-wol) kernel module using DKMS, investigated a network connectivity failure caused by the driver reload, and restored the Linux bridge configuration.

**Outcome:** Successfully verified Wake-on-LAN from a full shutdown using a Magic Packet sent from a Windows PC over the local network.

**Key concepts:** Linux kernel modules, DKMS, device drivers, network interfaces, Linux bridging, and systematic troubleshooting.

[Read the full troubleshooting case study](docs/04-wake-on-lan-alx-dkms.md)

---

## Windows Wake-on-LAN Utilities

The repository provides two separate workflows:

- **Local LAN WoL:** [`scripts/Wake-Proxmox.ps1`](scripts/Wake-Proxmox.ps1) sends a 102-byte Ethernet Magic Packet via UDP broadcast.
- **Remote ESP32/Tailscale WoL:** [`scripts/Wake-Proxmox-VPN.ps1`](scripts/Wake-Proxmox-VPN.ps1) submits ASCII `wake\n` (5 bytes) to the ESP32 Tailnet address, optionally checks a Tailscale ping preflight, receives application `ok` ACKs and independently polls Proxmox TCP/8006.

Run [`scripts/Start-Proxmox.cmd`](scripts/Start-Proxmox.cmd) on Windows to choose **L** (LAN), **R** (Remote) or **Q** (Quit). The launcher uses script-relative paths and reads a trusted local `scripts/proxmox.local.cmd`. Copy the [example configuration](scripts/proxmox.local.example.cmd), replace its placeholders privately and **never commit your real configuration**. See the [complete launcher guide](scripts/README-launcher.md).

For a DERP-only gateway whose default Tailscale ping does not succeed, `MAX_PING_ATTEMPTS=0` skips the optional ping check but keeps the required VPN/peer checks. No Internet-facing port forwarding is needed.

A typical **local** command (example values only):

```powershell
.\scripts\Wake-Proxmox.ps1 `
    -MacAddress "AA:BB:CC:DD:EE:FF" `
    -BroadcastAddress "192.0.2.255" `
    -TargetIPAddress "192.0.2.10" `
    -OpenBrowser
```

The host TCP service becoming reachable is not proof of boot causality, authenticated login or full host health. Historical wake, regression and remote acceptance results are documented in [Lab 05](docs/05-powershell-wol-automation.md) and [Lab 06](docs/06-esp32-remote-wol-gateway.md). The final local scripts were supplied for publication; this exact GitHub revision still requires Windows PowerShell runtime acceptance.

## Learning Roadmap

Planned areas of exploration include:

- Virtual machines and Linux containers (LXC)
- Virtual networking and infrastructure security
- Storage management and backups
- Docker workloads within virtual machines
- Continued validation and security hardening of remote administration
- Monitoring and infrastructure automation

These are learning objectives, not completed implementations.

## Project Status

**Active — ongoing homelab development.**

This is a personal learning and experimentation environment, not a production infrastructure deployment.

## Acknowledgements

Thanks to the contributors of [AndiWeiss/alx-wol](https://github.com/AndiWeiss/alx-wol) for providing the modified Ethernet driver used in the Wake-on-LAN experiment.
