# Proxmox VE Installation and Initial Host Verification

> **Lab 01 — Completed setup / documented retrospectively**  
> **Scope:** One repurposed laptop running a single Proxmox VE host. This is a learning homelab, not a production cluster or cloud platform.

## Objective

Prepare a physical machine as a virtualization host and verify that Proxmox VE, the Linux kernel, hardware virtualization, and the management interface are available.

This document records the environment and checks observed during my initial setup. It is **not a verbatim installation transcript**: some installer selections and the original USB preparation steps were not preserved, so I do not present them as verified actions.

## Environment

| Component | Observed configuration |
| --- | --- |
| Host hardware | Toshiba Satellite C75-A (PSCE6E-003002GE) |
| Hypervisor | Proxmox VE 9.2.2 |
| Base operating system | Debian-based Proxmox VE (Debian 13 / Trixie generation) |
| Kernel at initial verification | `7.0.2-6-pve` |
| Management access | Proxmox HTTPS Web UI on TCP port `8006` |
| Physical networking | Wired Ethernet; a Linux bridge named `vmbr0` |
| Virtualization device | `/dev/kvm` present |

The project began with installation media prepared on USB and Proxmox VE installed on the laptop. The host was then administered through its local console and the Web UI from another computer on the same LAN.

## What Proxmox VE provides

Proxmox VE is a **bare-metal virtualization platform**: it runs on the physical host and uses a Linux kernel with KVM/QEMU for virtual machines and LXC for system containers.

A useful distinction for this homelab:

- **Physical host:** the Toshiba laptop and its CPU, memory, storage, and NIC.
- **Hypervisor environment:** Proxmox VE manages virtualized workloads and host resources.
- **VM:** a guest with its own operating-system kernel, typically running through KVM/QEMU.
- **LXC container:** an OS-level isolated environment that shares the host Linux kernel.
- **Web management interface:** the HTTPS application/API exposed by Proxmox on port `8006`.

Installing Proxmox does not by itself constitute building a private cloud: additional capabilities and operational practices would be needed to justify that description.

## Initial verification

The following read-only commands were used or examined during initial setup:

```bash
pveversion
uname -r
ls -l /dev/kvm
ip -br addr
```

Observed software version:

```text
pve-manager/9.2.2 (running kernel: 7.0.2-6-pve)
```

The device `/dev/kvm` existed, indicating that the KVM device interface was available to the host. This is an important prerequisite for hardware-assisted virtual machines, although VM performance and compatibility need their own workload tests.

### Management UI

The Proxmox Web UI was reached from a separate Windows computer on the local network over HTTPS:

```text
https://<management-ip>:8006
```

The machine was kept on Ethernet for this stage. The actual relationship between the physical NIC, bridge, and host management IP is documented in [Lab 02 — Linux Networking](02-linux-networking.md).

## Operating a laptop as a headless host

A laptop normally reacts to lid closure by suspending or sleeping. This is undesirable for a continuously reachable hypervisor, so I configured systemd-logind to ignore lid-close events.

The following **configuration intent** was used in `/etc/systemd/logind.conf.d/10-headless.conf`:

```ini
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

This allowed the laptop to keep running with the lid closed. It should not be confused with a shutdown or Wake-on-LAN configuration. Laptop thermal management, ventilation, and power supply should still be considered.

## Safe operation and checks

```bash
# Show Proxmox version
pveversion

# Show the kernel currently running
uname -r

# Show a concise view of network interfaces and IP addresses
ip -br addr

# List the KVM device if available
ls -l /dev/kvm
```

Normal reboots and shutdowns should be initiated with guest workloads taken into account (for example, using the Proxmox Web UI and allowing configured guest shutdown procedures to finish). A forced power-off is not an equivalent routine shutdown.

## Result and limitations

**Verified:** Proxmox VE booted on the Toshiba, exposed `/dev/kvm`, and was reachable through its Web UI on the local network. The laptop was configured to continue operating when its lid closed.

**Not claimed:** any specific disk partitioning scheme, installer screenshots, production hardening, completed VM deployments, public Internet access, or a multi-node Proxmox cluster.

## Next labs

- [02 — Linux Networking and the `vmbr0` bridge](02-linux-networking.md)
- [03 — Wake-on-LAN with `alx-wol` and DKMS](04-wake-on-lan-alx-dkms.md)
