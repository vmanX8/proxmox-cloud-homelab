# Lab 03 — Tailscale VPN & Remote Access

> **Status:** Functional acceptance passed (11 November 2026). Ongoing security review is tracked separately.
>
> **Scope:** Private VPN management access to a single Proxmox VE host, including an externally triggered wake-to-ready test. This is a learning homelab, **not a production-secure remote administration solution**.

## 1. Goal and environment

Provide remote access to the home Proxmox hypervisor from outside its LAN without exposing the Proxmox management port publicly, and validate an optional wake path through an always-on ESP32 gateway.

| Component | Tested configuration |
| --- | --- |
| Host | Repurposed Toshiba Satellite C75-A |
| Hypervisor | Proxmox VE 9.2.2 |
| Operating system | Debian GNU/Linux 13.5 (Trixie) |
| Wired NIC / bridge | Qualcomm Atheros AR8162, physical `nic0`, Linux bridge `vmbr0` |
| Host VPN | Tailscale `tailscaled`, installed directly on Proxmox |
| Remote clients | Tablet on mobile data / hotspot, and an authorized Windows work laptop |
| Wake gateway | ESP32-WROOM-32D on the home LAN, joined to the same Tailnet |
| Web interface | HTTPS / TCP `8006` |

**Privacy:** Actual LAN addresses, Tailnet addresses, MAC addresses, account identifiers, login links, and credentials are deliberately omitted.

## 2. Architecture: management path vs power-on path

These are two **different** network flows:

```text
REMOTE MANAGEMENT (host is running)
Work laptop / mobile tablet
        |  private Tailscale connectivity
        v
 Proxmox host (tailscaled)
        |  HTTPS :8006
        v
 Proxmox Web UI / authenticated Shell

REMOTE WAKE (host is powered down)
Work laptop with Tailscale
        |  one UDP "wake\n" trigger, port 9999
        v
 ESP32 gateway (always on, Tailnet + home Wi-Fi)
        |  local LAN WoL Magic Packet
        v
 Toshiba Ethernet NIC -> power on -> Proxmox boot
        |  Tailscale reconnects after startup
        v
 Proxmox HTTPS :8006 becomes reachable
```

The Proxmox management IP remains assigned to `vmbr0`, which uses the physical Ethernet interface `nic0`. Tailscale adds its own virtual overlay interface rather than replacing this bridge. No subnet router or exit node was configured in this lab.

The ESP32 firmware is a separate, adapted third-party project; see [ESP32-WoL](https://github.com/vmanX8/ESP32-WoL). The earlier local-WoL driver work belongs to **Lab 04**, currently retained at a legacy filename: [WoL & alx DKMS](03-wake-on-lan-alx-dkms.md).

## 3. Installation and host checks — executed

The following commands were used on the Proxmox host. URLs below are official package repository paths, **not** one-time login URLs.

```bash
cat /etc/os-release
ip -br addr
ip route

mkdir -p -m 0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list

apt update
apt-get -s install tailscale
apt install tailscale
systemctl enable --now tailscaled
systemctl is-active tailscaled
tailscale up --accept-dns=false --accept-routes=false
tailscale status
tailscale ip -4
```

### Recorded findings

- Debian 13.5 (Trixie); the private LAN address and default route were on `vmbr0`.
- The APT simulation proposed **two new packages** (`tailscale` and its archive keyring), with **no package removals**. The installed Tailscale package was version `1.104.5` in the recorded output.
- `systemctl is-active tailscaled` returned `active`.
- The first `tailscale up` authentication attempt was interrupted; the second returned `Success.`
- `tailscale status` showed the Proxmox node and `tailscale ip -4` returned a Tailnet address.
- Host DNS acceptance and route acceptance were disabled explicitly using `--accept-dns=false --accept-routes=false`. No change to the LAN bridge or public port-forwarding was recorded.

## 4. External access validation

### Initial tablet test — passed

With the tablet using mobile data / hotspot rather than the home LAN, the remote user:

1. Enabled Tailscale and accessed the Proxmox HTTPS Web UI using its Tailnet address on port `8006`.
2. Completed Web UI authentication.
3. Executed `pwd` in the Proxmox Shell.
4. Initiated a remote shutdown successfully.

This demonstrates authenticated management from a different network; **remote shutdown is not remote power-on**.

### Final work-laptop acceptance — 11 November 2026

A Windows work laptop joined the Tailnet and saw the Proxmox and ESP32 peers. Basic ICMP reachability to the ESP32 was accepted for this lab, while TSMP/DISCO diagnostic timeouts remain separate known issues.

**Sanitized diagnostic evidence:**

```powershell
tailscale status
tailscale ip -4
ping -n 3 <ESP32_TAILSCALE_IP>
tailscale ping --icmp --c=3 <ESP32_TAILSCALE_IP>
tailscale ping --tsmp --c=3 <ESP32_TAILSCALE_IP>
Test-NetConnection <PROXMOX_TAILSCALE_IP> -Port 8006 -InformationLevel Quiet
```

| Check | Observed result | Lab 03 decision |
| --- | --- | --- |
| Windows ICMP to ESP32 | 3 sent / 3 received / 0% loss | PASS |
| Windows ICMP round-trip | min 619 ms; avg 1022 ms; max 1806 ms | High latency, captured as observed |
| Tailscale `--icmp` | A reply recorded at 668 ms | PASS for observed reachability |
| Tailscale `--tsmp` | Three timeouts, no reply | Known issue, tracked elsewhere |
| Default `tailscale ping` | Timeouts | Known issue, tracked elsewhere |
| TCP :8006 baseline | Unreachable before the controlled wake measurement | Baseline only; not physical shutdown proof |
| UDP trigger | One `wake\n` payload, 5 bytes accepted for sending | Sent; not proof of ESP32 receipt |
| First successful TCP :8006 | 31.7 seconds after wake trigger | PASS |
| Work-laptop browser login | Login and Proxmox dashboard shown | PASS |
| Phone browser | Proxmox dashboard also confirmed | PASS |

The controlled test used **one** UDP send to the ESP32 Tailnet IP on port `9999`. A Windows `UdpClient.Send()` return value of 5 indicates that the local socket accepted a 5-byte payload; it does not prove a remote acknowledgement. The successful service recovery after the trigger, together with earlier independent ESP32 wake demonstrations, supports the operational end-to-end conclusion.

**Exact timestamps from the final test (local clock):**

```text
T0 — UDP send:                 15:22:32.016
T1 — first successful TCP:     15:23:03.675
Measured wake-to-TCP:          31.7 seconds
TCP check result:              PASS
Web UI login/dashboard:        PASS
```

The time above is **trigger-to-first-observed-TCP-connect**, **not** a stopwatch measurement of BIOS startup or full guest readiness. The polling procedure checks repeatedly, so the first *observed* success can occur later than the moment the service actually became ready.

### How the controlled Windows test worked

The test script (run directly in PowerShell, not represented as an uploaded launcher release) performed:

1. Preflight: check if Proxmox already accepted TCP connections on 8006; abort the wake attempt if already ready.
2. Record `T0` and send the literal ASCII `wake\n` over UDP to the ESP32 listener on `9999`.
3. Poll TCP `8006` with 1.5-second connect waits and 3-second intervals, stopping after the first successful connect or after a 300-second maximum.
4. Record `T1` and elapsed time, then authenticate manually through the Proxmox Web UI.

The existing `scripts/Wake-Proxmox.ps1` in this repository is a **different** utility: it sends a LAN WoL Magic Packet (normally UDP port 9) to the target NIC. Its TCP polling does not imply the ESP32-based trigger is integrated into that script. A combined Windows launcher remains a separate scope.

## 5. Security, known limitations, and scope boundaries

- The Proxmox interface was reached via its private Tailnet endpoint. No public forwarding of TCP `8006` was configured as part of this lab.
- Tailscale encryption does not replace Proxmox authentication, Tailnet grants/ACLs, device security, or MFA. **No dedicated ACL/grants audit or MFA hardening was validated in this chat.**
- The ESP32 adaptation is **not production-secure**. Its repository documents unverified DERP TLS server certificates and a wake-command authorization model still requiring review. Do not publicly expose the ESP32 UDP listener.
- The observed high ICMP latency and TSMP/DISCO failures are tracked in the **HL-06 / HL-R06** investigations; they do not invalidate the basic external management acceptance test.
- TCP port readiness is not proof of successful authentication, VM readiness, or overall system health. Manual Web UI login was verified separately.
- The work laptop was authorized to use Tailscale; this is not a recommendation to bypass workplace security controls.
- Long-term reliability, reconnections, monitoring, guest VM connectivity, and security policy hardening remain unverified.

## 6. Related labs and lessons learned

| Lab | Relationship |
| --- | --- |
| Lab 01 — Host baseline | Provides the installed Proxmox host and Web UI |
| Lab 02 — Linux networking | Provides `nic0`, `vmbr0`, and the LAN gateway |
| Lab 04 — Wake-on-LAN / alx DKMS | Enables local Ethernet power-on; separate from VPN reachability |
| Lab 06 — ESP32 Remote WoL Gateway | Receives the VPN trigger and emits LAN Magic Packets |

**Lessons:** Separate overlay reachability from local bridging, transport-level readiness from app authentication, shutdown from wake-up, and successful UDP send from proof of remote receipt. The successful work-laptop wake-to-TCP run is a **functional integration result**, not evidence that all security or resilience issues are solved.

## 7. Closure

**Lab 03 acceptance: PASS — 11 November 2026.** The core objective (authenticated remote Proxmox administration over Tailscale from outside the home network) was demonstrated on both mobile and work-laptop clients. The optional ESP32 wake integration also passed one controlled service-recovery measurement at **31.7 seconds**. Known ESP32 and network diagnostic issues remain tracked separately.

No production-readiness claim is made. No migration/rename of legacy lab filenames is performed in this documentation change.
