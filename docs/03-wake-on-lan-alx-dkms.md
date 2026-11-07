# Wake-on-LAN on Proxmox VE with `alx-wol` (DKMS)

## Overview

**Status:** Successfully tested on the local network, including power-on from a full shutdown.

This case study documents how I enabled Wake-on-LAN (WoL) on a repurposed Toshiba laptop running Proxmox VE. The original Linux `alx` Ethernet driver did not expose the required WoL support. I used the community-maintained [`AndiWeiss/alx-wol`](https://github.com/AndiWeiss/alx-wol) project to install a patched driver through DKMS, recovered a temporary Linux bridge connectivity issue, and verified the result with a real Magic Packet test.

This was an **integration and troubleshooting exercise**, not development of the upstream Ethernet driver.

## Test environment

| Component | Configuration |
| --- | --- |
| Host | Toshiba Satellite C75-A (PSCE6E-003002GE) |
| Hypervisor | Proxmox VE 9.2.2 |
| Kernel at time of test | `7.0.2-6-pve` |
| Ethernet chipset | Qualcomm Atheros AR8162 (`1969:1090`) |
| Original kernel driver | `alx` |
| Patched module | `alx-wol` 3.3 (DKMS) |
| Physical interface | `nic0` |
| Linux bridge | `vmbr0` |
| BIOS setting | Wake-up on LAN enabled |
| Magic Packet sender | Windows PowerShell on the same LAN |

> IP addresses and MAC addresses are deliberately omitted from this public write-up. Replace placeholders in commands with values appropriate to your own network.

## 1. Problem and initial diagnosis

The BIOS had a Wake-up on LAN option, but the original driver did not make WoL available through `ethtool`.

```bash
ethtool nic0 | grep -i wake
ethtool -s nic0 wol g
```

The second command returned `Operation not supported` with the original driver.

To distinguish a packet-delivery problem from a driver/hardware problem, I inspected incoming traffic while the Proxmox host was running:

```bash
tcpdump -ni nic0 -c 1 'udp dst port 9'
```

A Magic Packet sent from Windows reached the interface. This **only confirmed packet delivery while Linux was running**; it did not confirm the ability to wake the machine from shutdown.

## 2. Installing the patched driver

The upstream project is [AndiWeiss/alx-wol](https://github.com/AndiWeiss/alx-wol). I reviewed its installation scripts before using them, especially because the install hook can unload/reload the live Ethernet module and rebuild the initramfs.

Preparation included installing DKMS, build tools, Git, and the **headers matching the running Proxmox kernel**. I also backed up the original `alx.ko` and the boot initramfs before modifying the system.

Commands used during the DKMS workflow included:

```bash
uname -r
# Confirm the matching kernel headers are installed before proceeding.

git clone https://github.com/AndiWeiss/alx-wol.git
cd alx-wol

dkms add -m alx-wol -v 3.3
dkms build -m alx-wol -v 3.3 -k "$(uname -r)"
dkms install -m alx-wol -v 3.3 -k "$(uname -r)"
```

**Important:** These are a record of the workflow, **not a universal copy-paste installer**. DKMS source registration, dependencies, patches, and installation hooks must be checked against the upstream instructions and the running kernel. Run network-driver changes with **physical console access**, not solely through SSH or a web shell.

After installation:

```bash
dkms status
ethtool nic0 | grep -i wake
```

The resulting output showed:

```text
alx-wol/3.3, 7.0.2-6-pve, x86_64: installed (Original modules exist)
Supports Wake-on: pg
Wake-on: pg
```

`Supports Wake-on` describes driver capabilities; `Wake-on` reports the currently enabled modes. `g` means wake on Magic Packet.

## 3. Troubleshooting: bridge connectivity lost after driver reload

After the live driver replacement, the physical Ethernet interface was re-created. It was no longer attached to the existing Proxmox Linux bridge, so the Web UI became unreachable.

Checks:

```bash
ip -br link
bridge link show
readlink /sys/class/net/nic0/master
```

The physical interface eventually showed carrier (`LOWER_UP`), but the bridge had no attached port (`NO-CARRIER`). From the **local console**, I restored the configuration:

```bash
ip link set nic0 up
ip link set nic0 master vmbr0
ip link set vmbr0 up
```

Verification:

```bash
bridge link show
ip -br link
```

The bridge reported `nic0 ... master vmbr0 state forwarding`, and the Proxmox Web UI became reachable again. Following a reboot, the interface and bridge came up automatically without repeating these commands.

**Key distinction:** `UP` is the administrative state of an interface; `LOWER_UP` indicates an operational lower-layer link. A bridge can be administratively up while having no connected port.

## 4. Full shutdown / power-on verification

Before the final test, I enabled Magic Packet wake explicitly:

```bash
ethtool -s nic0 wol g
ethtool nic0 | grep -i wake
```

Expected configuration:

```text
Supports Wake-on: pg
Wake-on: g
```

I then performed a **normal shutdown** with the laptop connected to AC power and Ethernet. From a Windows PC on the same LAN, I sent a 102-byte Magic Packet: six `0xFF` bytes followed by the NIC's six-byte MAC address repeated 16 times.

**Observed result:** The Toshiba powered on without pressing the physical power button, Proxmox booted, and the Web UI was reachable.

This test confirms **local LAN WoL from a full shutdown** for the configuration above. It does not demonstrate wake from the public Internet or secure remote administration; those remain separate future tasks.

## 5. Additional observation: slow reboot

A separate reboot briefly appeared stuck at a blinking underscore cursor during the shutdown/restart transition. The previous boot journal showed a `pveproxy.service` stop timeout of approximately 92 seconds, after which systemd killed the remaining worker and completed the reboot. There was **no evidence establishing that the patched Ethernet driver caused this delay**.

Useful commands:

```bash
journalctl --list-boots
journalctl -b -1 -e --no-pager
systemd-analyze time
```

`systemd-analyze time` measures startup duration, **not the time taken to shut down the previous boot**.

## 6. Lessons learned and maintenance notes

- WoL depends on BIOS/firmware, the NIC, driver support, standby power, and delivery of a valid Magic Packet.
- Troubleshoot networking in layers: physical NIC → kernel driver → interface → Linux bridge → IP connectivity → Proxmox Web/API service.
- A kernel module replacement may interrupt networking, even if the newly installed module is working correctly.
- Keep backups and ensure console access before modifying a hypervisor's primary network driver.
- `DKMS installed` and `Magic Packet sent` are **not equivalent** to successful remote power-on; perform a real shutdown-and-wake test.
- A future Proxmox kernel upgrade may require rebuilding or updating the out-of-tree module. Verify `dkms status`, the bridge, WoL settings, and power-on again after upgrades.
- Credit the upstream project. I did not author the patched `alx` driver.

## Credits

Patched driver: [AndiWeiss/alx-wol](https://github.com/AndiWeiss/alx-wol). Thanks to its maintainers and contributors.
