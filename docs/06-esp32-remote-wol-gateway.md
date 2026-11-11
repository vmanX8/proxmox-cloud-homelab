# Lab 06 — ESP32 Remote Wake-on-LAN Gateway

> **Status:** Remote wake functionality validated on real hardware. Firmware reliability and security validation remain open; this is **not production-ready**.

## 1. Objective and system architecture

A powered-off Proxmox host cannot run Tailscale. An independently powered ESP32-WROOM-32D gateway remains connected to the home Wi-Fi network and its Tailscale network, receives a remote application UDP trigger on port `9999`, and broadcasts a standard Wake-on-LAN Magic Packet over the local network to the Toshiba Ethernet NIC.

```text
Windows or mobile Tailscale client
           |
    Tailscale / WireGuard (observed DERP relay)
           |
    ESP32-WROOM-32D -- application UDP / 9999
           |               |
           |         optional "ok" reply after
           |         local WoL send submission
           |
       LAN broadcast -- UDP / 9
           |
    Toshiba Ethernet NIC --> Proxmox starts
                                   |
                       Proxmox HTTPS TCP / 8006
                       checked independently by client
```

The remote application UDP request is **not** itself the Magic Packet. The ESP32 builds and sends a separate 102-byte WoL packet on the LAN. An `ok` reply acknowledges local submission, **not successful host boot**.

The ESP32 is **not** a general-purpose Tailscale subnet router and does not host the Proxmox management UI. See [Lab 03 — Tailscale management access](03-tailscale-vpn-remote-access.md) and [Lab 04 — Ethernet WoL prerequisite](04-wake-on-lan-alx-dkms.md).

## 2. Implementation and code ownership

The gateway is an adaptation of [medinajaime/esp32-wakeonlan](https://github.com/medinajaime/esp32-wakeonlan), with a WireGuard/lwIP dependency from [smartalock/wireguard-lwip](https://github.com/smartalock/wireguard-lwip). Build, firmware source, upstream attribution, component licenses and detailed security validation belong in the independent [ESP32-WoL repository](https://github.com/vmanX8/ESP32-WoL).

The application can use DERP-relayed WireGuard traffic to carry the trigger when a direct peer path is unavailable. Direct STUN/DISCO negotiation is not part of the **tested DERP-only application configuration** of the newer experimental firmware.

**Version boundary:** The public ESP32 repository's default branch documents the earlier end-to-end validated firmware. Later reliability fixes and their test evidence are available in a [separate experimental branch comparison](https://github.com/vmanX8/ESP32-WoL/compare/main...fix/hl06-esp32-derp-reliability). This document does not claim that unmerged experimental code is already released on `main`.

## 3. Verification

### Physical wake-up and management access

The gateway was tested with an Ethernet-connected Toshiba Satellite C75-A running Proxmox VE:

| Test | Observed result | Verification boundary |
| --- | --- | --- |
| Remote wake via Android Tailscale client | Two successful complete-shutdown wake cycles, with a shutdown between attempts | Actual host boot and GUI access |
| Remote-laptop wake and reconnect | Successful remote wake after confirmed shutdown in field tests | Functional remote power-on; repeated reliability still under evaluation |
| Proxmox HTTPS availability | TCP `8006` became reachable; Web UI login was separately confirmed | Availability of one service, not full system/VM readiness |
| Controlled trigger-to-TCP observation | Approximately **31.7 seconds** | Host's physical shutdown state not separately witnessed in that specific timed run |

See the [documented ESP32 validation baseline](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md).

### Application UDP acknowledgment tests

Further tests on the experimental DERP-only firmware investigated UDP reception and replies:

| Metric | Earlier observed sample | Experimental firmware sample | Limit |
| --- | --- | --- | --- |
| Windows application `ok` acknowledgments | 31/40 (77.5%) | **40/40 (100%)** | Separate short-run observations, not controlled A/B testing |
| Experimental ACK latency | No equivalent full baseline | 498–893 ms; mean approximately 603 ms | Includes relay and client/network latency |
| Device-side UDP reception, local WoL submission and ACK submission | Partial older measurements | 40/40 observed for each | **Not** 40 independent physical boot tests |
| 16–24-hour endurance | Not established | **Not performed** | No uptime or reliability guarantee |

The experimental firmware is based on fixing receive re-entry, lwIP TCP/IP thread ownership, DERP frame ownership, peer mapping and callback lifetimes. These are reviewed source-level improvements; the evidence does not isolate the contribution of any single change or prove that all race conditions are eliminated.

Details and source diff: [experimental firmware branch](https://github.com/vmanX8/ESP32-WoL/tree/fix/hl06-esp32-derp-reliability) and [comparison against published firmware](https://github.com/vmanX8/ESP32-WoL/compare/main...fix/hl06-esp32-derp-reliability).

## 4. Troubleshooting and connectivity diagnostics

During external use, ordinary IP-layer and Tailscale-specific probes behaved differently:

| Probe | Observation | Interpretation |
| --- | --- | --- |
| Windows ICMP `ping` | 3/3 replies; RTT 619–1806 ms, average 1022 ms | IP connectivity exists, but latency is variable |
| `tailscale ping --icmp` | Successful ICMP reply observed at 668 ms | ICMP-over-tailnet connectivity works in the observed setup |
| `tailscale ping --tsmp` | Three timeouts | Embedded TSMP handling was not confirmed |
| Default `tailscale ping` | Timeouts in field tests | DISCO is disabled in the tested DERP-only firmware configuration |
| UDP wake request and `ok` ACK | Working in specific test runs | Application data-plane path can work despite default ping failures |

**Do not use a failed default Tailscale ping as the sole signal that this gateway is offline.** The probe does not test the same application UDP listener. The field results demonstrate functional wake traffic even when default Tailscale ping times out.

A further launcher troubleshooting issue was a ping preflight that blocked otherwise usable remote-wake traffic. A configurable diagnostic bypass and bounded UDP ACK retries were tested locally. The public [LAN-direct PowerShell sender](../scripts/Wake-Proxmox.ps1) remains a separate utility; **the later remote launcher is not included in the published Proxmox scripts**. See [Lab 05](05-powershell-wol-automation.md) for the automation boundary.

**Non-destructive diagnostics:** ICMP is available for connectivity checks. **Do not send application UDP `ping` to port `9999` on the current firmware**: its wake listener accepts any received UDP payload as a wake request, so `ping` can trigger an actual WoL broadcast.

### Reliability issues still under investigation

- Connection degradation after extended uptime and repeated reconnects.
- DERP receive-buffer and TLS teardown stalls; current synchronous waits may be unbounded.
- Peer churn, WireGuard slot mapping, heap fragmentation, task stack and power-supply stability.
- An application-level non-destructive `ping`/`pong` contract is a **proposed future change**, not an implemented feature.

## 5. Security boundaries

1. **Critical blocker:** The reviewed DERP TLS client uses `MBEDTLS_SSL_VERIFY_NONE`; DERP server certificate verification has not been established.
2. **Command acceptance:** The current application does not restrict incoming UDP to an exact, authorized `wake` payload. An authenticated, restricted tailnet and reviewed ACLs/grants are needed; a public router port-forward must **not** expose this listener.
3. **Long-term reliability:** Short tests and successful physical boots do not establish production endurance, failure recovery or security.

This is an experimental homelab integration, **not a production-secure or high-availability service**.

## 6. Related documentation

- [Lab 03 — Tailscale VPN & Remote Access](03-tailscale-vpn-remote-access.md)
- [Lab 04 — Wake-on-LAN & DKMS](04-wake-on-lan-alx-dkms.md)
- [Lab 05 — PowerShell WoL Automation](05-powershell-wol-automation.md)
- [Architecture overview](ARCHITECTURE.md)
- [ESP32 firmware: attribution](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/UPSTREAM_ATTRIBUTION.md)
- [ESP32 firmware: validated limitations](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md)
