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