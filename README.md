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

## Wake-on-LAN Utility

The repository includes a reusable PowerShell script for sending Wake-on-LAN Magic Packets from Windows.

**Script:** [`scripts/Wake-Proxmox.ps1`](scripts/Wake-Proxmox.ps1) — [Lab 05 implementation and verification](docs/05-powershell-wol-automation.md)

### Usage

Run the script from PowerShell in the repository's root directory:

```powershell
.\scripts\Wake-Proxmox.ps1 `
    -MacAddress "AA:BB:CC:DD:EE:FF" `
    -BroadcastAddress "192.0.2.255"
```

The MAC and the TEST-NET IPv4 examples are illustrative only. Replace them with the correct values for your actual network before running.

### Parameters


| Parameter | Description | Required |
|---|---|---|
| `MacAddress` | Target device MAC address | Yes |
| `BroadcastAddress` | Destination broadcast IPv4 address | Yes |
| `Port` | UDP port (default: 9) | No |
| `SourceIPAddress` | Local IP used to send the packet | No |
| `TargetIPAddress` | Server IP used for TCP availability checks | No |
| `TargetPort` | Target TCP port (default: 8006) | No |
| `MaxAttempts` | Maximum TCP checks (default: 18) | No |
| `IntervalSeconds` | Delay between checks (default: 5) | No |
| `OpenBrowser` | Open the target URL in the default browser | No |


### Requirements

- Windows PowerShell or PowerShell with .NET networking support.
- A target device configured to support Wake-on-LAN.
- A network path that permits delivery of the Magic Packet.
- A PowerShell execution policy that permits running the script.

**Note:** When `TargetIPAddress` is provided, the script also verifies TCP connectivity to the specified port. This confirms service reachability, not full application health or definitive proof that the Magic Packet caused the device to power on.

The utility was successfully tested with a Toshiba Satellite C75-A running Proxmox VE 9.2.2, using the community-maintained `alx-wol` driver.


### Wake and Check Server Availability

```powershell
.\scripts\Wake-Proxmox.ps1 `
    -MacAddress "AA:BB:CC:DD:EE:FF" `
    -BroadcastAddress "192.0.2.255" `
    -TargetIPAddress "192.0.2.10" `
    -OpenBrowser
```

The script checks whether the target service is already reachable.
If it is offline, the script sends a Magic Packet and periodically
checks TCP connectivity until the service becomes reachable or
the maximum number of attempts is reached.

The `-OpenBrowser` switch optionally opens the server URL when
TCP connectivity has been confirmed.

### Exit Codes

| Code | Meaning |
|---|---|
| `0` | Packet sent successfully, or target service reachable |
| `1` | Target service did not become reachable within the configured checks |

Exit code `0` does not guarantee that the device powered on
when no availability check was requested.

**Note:** TCP connectivity confirms that the specified port accepts
connections. It does not perform a full application health check.

### Windows Launcher Verification

A local Windows `.cmd` launcher was configured to execute the
PowerShell utility with the homelab-specific parameters.

The launcher was successfully tested with the Proxmox host
fully shut down, confirming remote wake-up and subsequent
availability of the Web GUI.

**Example:**

```bat
@echo off
title Proxmox Wake-on-LAN
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "[Full Windows project location]\scripts\Wake-Proxmox.ps1" -MacAddress "AA:BB:CC:DD:EE:FF" -BroadcastAddress "192.0.2.255" -SourceIPAddress "192.0.2.x" -TargetIPAddress "192.0.2.x" -OpenBrowser
echo Script exit code: %ERRORLEVEL%
pause
```

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
