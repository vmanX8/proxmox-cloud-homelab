# Linux Networking on a Proxmox VE Host

> **Lab 02 — Completed configuration / documented retrospectively**  
> **Scope:** Wired management networking and a Linux bridge (`vmbr0`) on a single Proxmox VE host.

## Objective

Understand how a physical Ethernet interface participates in a Linux bridge and how that bridge provides network connectivity to the Proxmox management host and, potentially, future guests.

This case records configuration and checks observed in the homelab; it does not imply that any VM or LXC guest was already connected to the bridge.

## Environment and topology

| Component | Observed value |
| --- | --- |
| Hypervisor | Proxmox VE 9.2.2 |
| Physical Ethernet device | Qualcomm Atheros AR8162 (`1969:1090`) |
| Linux interface | `nic0` |
| Linux bridge | `vmbr0` |
| Bridge role | Host management network / future guest uplink |
| LAN | Private Ethernet network |
| Management protocol | HTTPS on TCP port `8006` |

For security and portability, this public document intentionally omits real local IP and MAC addresses.

```text
Windows management PC
         |
      LAN switch/router
         |
  Toshiba Ethernet adapter
         |
      nic0 (physical interface)
         |
      vmbr0 (Linux bridge) ------ future VM / LXC ports
         |
  Proxmox host management IP
         |
  HTTPS management UI :8006
```

## Mental model: NIC versus bridge

`nic0` represents the **physical network interface**. `vmbr0` is a **software bridge**, similar to a virtual Ethernet switch. Its ports can connect the physical NIC and guest virtual interfaces at Layer 2.

On this host the management IP is configured on `vmbr0`, rather than using a separate management IP on `nic0`. The bridge provides the logical networking endpoint; `nic0` carries frames between the bridge and the wired LAN.

The exact persisted contents of `/etc/network/interfaces` were not captured for this report, so no invented configuration file is presented as an exact backup.

## Read-only diagnostic commands

```bash
ip -br addr
ip -br link
bridge link show
ip -d link show vmbr0
readlink /sys/class/net/nic0/master
ethtool nic0
```

| Command | What it tells us |
| --- | --- |
| `ip -br addr` | Interfaces and assigned IP addresses |
| `ip -br link` | Interface administrative and operational states |
| `bridge link show` | Which ports belong to bridges and whether they forward traffic |
| `ip -d link show vmbr0` | Additional details about the bridge |
| `readlink .../master` | Which master bridge/interface owns `nic0` |
| `ethtool nic0` | Ethernet link, negotiated speed/duplex, and supported features |

### Important state distinctions

- `UP` means the interface is **administratively enabled**.
- `LOWER_UP` indicates an active underlying link/carrier.
- `NO-CARRIER` means there is no operational lower-layer link.
- `state forwarding` on a bridge port means the port is able to forward Ethernet frames.

An administratively `UP` bridge can still be operationally down when it has no connected carrier-bearing port.

## Real troubleshooting event: driver reload and bridge membership

During [Lab 04](03-wake-on-lan-alx-dkms.md), a community-maintained replacement `alx` kernel module was installed for Wake-on-LAN support. The reload unregistered and recreated the Ethernet interface, and the existing bridge lost its physical member.

Symptoms:

- Ethernet eventually reported link carrier and `100 Mb/s Full`.
- `vmbr0` had no usable carrier and the Web UI became unreachable.
- `bridge link show` displayed no enslaved port.
- `readlink /sys/class/net/nic0/master` returned no bridge relationship.

Recovery was performed **from the laptop's physical console**:

```bash
ip link set nic0 up
ip link set nic0 master vmbr0
ip link set vmbr0 up
```

Then:

```bash
ip -br link
bridge link show
```

The observed bridge-port state was:

```text
nic0 ... master vmbr0 state forwarding
```

The Proxmox Web UI became reachable again. After a normal reboot, `nic0` and `vmbr0` returned automatically without running those recovery commands again.

> **Operational caution:** `ip link set` changes live networking. Changing a hypervisor's only uplink through remote access can disconnect the administrator. Always arrange console access and know how to restore the persisted configuration.

## Connectivity validation

The Proxmox Web UI was the practical end-to-end management check. A failed ICMP ping to a Windows host was **not** taken as definitive proof of network failure, since a host firewall may block ICMP Echo Requests.

```bash
ping -c 4 <lan-host-ip>
```

An explicit TCP check can be more relevant for a specific service; the separate Windows Wake-on-LAN utility checks the Proxmox HTTPS port to report whether the management endpoint is reachable.

## Result and lessons learned

**Verified:** A functioning physical Ethernet link; `nic0` attached as a forwarding port of `vmbr0`; the host management UI reachable over the LAN; bridge membership recovered automatically following a reboot.

**Key lesson:** Troubleshoot in layers:

```text
Physical link -> NIC driver -> nic0 -> bridge membership -> vmbr0 -> IP -> management service
```

A reachable network interface is not sufficient if the Linux bridge is missing its physical member. Likewise, a functioning bridge does not prove a particular application service is running.

## Related documentation

- [01 — Proxmox VE Installation and Initial Verification](01-proxmox-installation.md)
- [03 — Wake-on-LAN with `alx-wol` and DKMS](03-wake-on-lan-alx-dkms.md)
