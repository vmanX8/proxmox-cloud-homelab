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

## Labs & Documentation

### Wake-on-LAN with a custom Ethernet driver

The first documented troubleshooting case focuses on enabling Wake-on-LAN support for the Qualcomm Atheros AR8162 Ethernet adapter.

The original driver did not expose the required Wake-on-LAN functionality. After installing the modified [`alx-wol`](https://github.com/AndiWeiss/alx-wol) kernel module, remote power-on was successfully tested over the local network.

**Case study:** [Wake-on-LAN on Proxmox VE with `alx-wol` (DKMS)](docs/03-wake-on-lan-alx-dkms.md)

## Wake-on-LAN Utility

The repository includes a reusable PowerShell script for sending Wake-on-LAN Magic Packets from Windows.

**Script:** [`scripts/Wake-Proxmox.ps1`](scripts/Wake-Proxmox.ps1)

### Usage

Run the script from PowerShell in the repository's root directory:

```powershell
.\scripts\Wake-Proxmox.ps1 `
    -MacAddress "AA:BB:CC:DD:EE:FF" `
    -BroadcastAddress "192.168.1.255"
```

Replace the example MAC address and broadcast address with values appropriate for your network.

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
    -BroadcastAddress "192.168.1.255" `
    -TargetIPAddress "192.168.1.100" `
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

## Learning Roadmap

Planned areas of exploration include:

- Virtual machines and Linux containers (LXC)
- Virtual networking and infrastructure security
- Storage management and backups
- Docker workloads within virtual machines
- Secure remote administration
- Monitoring and infrastructure automation

These are learning objectives, not completed implementations.

## Project Status

**Active — ongoing homelab development.**

This is a personal learning and experimentation environment, not a production infrastructure deployment.

## Acknowledgements

Thanks to the contributors of [AndiWeiss/alx-wol](https://github.com/AndiWeiss/alx-wol) for providing the modified Ethernet driver used in the Wake-on-LAN experiment.
