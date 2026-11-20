# Lab 03 — Tailscale VPN & Remote Access

> **Status:** Functional remote administration validated. Security hardening and long-term reliability remain outside the completed acceptance scope.  
> **Environment:** Single Proxmox VE host; private Tailscale overlay; no public forwarding of the Proxmox management port.

## 1. Objective and environment

Enable authenticated administration of the Proxmox host from another network without exposing TCP port `8006` on the public Internet.

| Component | Verified configuration |
| --- | --- |
| Host | Toshiba Satellite C75-A running Proxmox VE 9.2.2 |
| Host OS at verification | Debian GNU/Linux 13.5 (Trixie) |
| Ethernet interface and bridge | Qualcomm Atheros AR8162, `nic0`, `vmbr0` |
| Host VPN | Tailscale daemon (`tailscaled`) installed on Proxmox |
| Remote clients | Tablet over mobile data/hotspot and an authorized Windows remote laptop |
| Management service | HTTPS, TCP `8006`; Proxmox login required |
| Optional wake gateway | Independently powered ESP32-WROOM-32D on the home LAN |

Actual LAN, Tailnet and MAC addresses, account identifiers, credentials and login links are omitted.

## 2. Architecture and responsibilities

**Remote management works when the Proxmox host is running:**

```text
Windows laptop / tablet on another network
         |
    Private Tailscale overlay
         |
Proxmox host (tailscaled) -- HTTPS :8006 --> Web UI / Shell
         |
       vmbr0 -- nic0 -- home Ethernet LAN
```

Tailscale adds an overlay interface; it does **not** replace the Proxmox management bridge `vmbr0`. This lab did not configure a Tailscale subnet router or exit node.

**Remote power-on is a separate integration:**

```text
Remote Tailscale client -- UDP trigger / 9999 --> ESP32 gateway
                                                  |
                                         LAN WoL Magic Packet
                                                  |
                                      Toshiba NIC --> Proxmox boot
                                                  |
                                   Tailscale / HTTPS :8006 ready
```

The ESP32 gateway is covered by [Lab 06 — Remote Wake-on-LAN](06-esp32-remote-wol-gateway.md). When the Proxmox host is powered off, its own Tailscale process cannot receive packets or wake the host.

## 3. Installation and configuration

The following commands were executed on the Proxmox host. The keyring and repository URLs are official package-distribution locations, not personal authentication links.

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

### Configuration and service verification

- The default LAN route and host management IP remained associated with `vmbr0`.
- The APT simulation reported two package additions and no removals. The recorded installed Tailscale version was `1.104.5` (not a statement about the latest available version).
- `tailscaled` reported `active`.
- Tailscale authentication completed successfully; `tailscale status` listed the Proxmox node and `tailscale ip -4` reported its private Tailnet address.
- The host explicitly declined Tailscale DNS and route acceptance using `--accept-dns=false --accept-routes=false`.
- No public port-forward to TCP `8006` was configured for this lab.

This installation procedure records the tested setup, not a recommendation to paste remote commands without reviewing them for the target operating system and current package instructions.

## 4. Functional validation

### Authenticated administration from outside the LAN

| Test | Result | What it confirms |
| --- | --- | --- |
| Tablet using mobile data/hotspot | **PASS** — connected to Proxmox HTTPS UI | Private remote service access |
| Tablet Web UI login | **PASS** | Application-level authentication |
| Tablet Proxmox Shell | **PASS** — `pwd` executed | Authenticated remote shell availability |
| Tablet remote shutdown | **PASS** | Administrative shutdown, **not** remote power-on |
| Windows remote laptop with Tailscale | **PASS** — Web UI login/dashboard | Authenticated access from a second remote client |
| Mobile phone dashboard | **PASS** | Additional browser access |

The remote client used an authorized Tailscale installation. Tailnet access does not replace Proxmox authentication or device-access policy.

### Optional ESP32 wake-to-service readiness

A controlled Windows test used a single unicast UDP `wake\n` datagram to the ESP32's Tailscale address on port `9999`. The target's TCP port `8006` was initially unreachable. The client then polled the port using bounded connection attempts and intervals.

| Measurement | Observed result |
| --- | --- |
| UDP trigger | One 5-byte payload submitted by the local socket |
| Pre-trigger TCP `8006` | Unreachable |
| First observed TCP `8006` success | **31.7 seconds** after trigger |
| Subsequent Web UI login/dashboard | **PASS** |

The 31.7-second result is **trigger-to-first-observed-TCP-connect**, not BIOS boot time or full VM readiness. The physical shutdown state was **not independently observed for this particular timed run**. Separate physically verified complete-shutdown wake tests are described in [Lab 06](06-esp32-remote-wol-gateway.md).

A successful `UdpClient.Send()` return value indicates local submission, **not** delivery or an ACK from the ESP32. TCP readiness and authenticated Web UI login were separately checked.

### Wake-to-service measurement procedure

The controlled remote-client test followed this sequence:

1. Confirm that the target Proxmox TCP port `8006` is not reachable before sending the trigger.
2. Record the start of the test, then submit **one** ASCII `wake\n` UDP datagram to the ESP32 Tailscale address on port `9999`.
3. Poll the Proxmox TCP endpoint with 1.5-second connect timeouts and 3-second intervals, stopping on the first successful connection or after a maximum observation window of 300 seconds.
4. Record the first observed TCP success and perform a separate browser login to verify the management UI.

The observed **31.7 seconds** measures trigger submission to the first successful TCP probe. It does not measure exact BIOS/OS boot time, validate guest readiness or establish that a UDP acknowledgment was received. The test used a PowerShell procedure on the remote client; it is **not** a claim that the separately developed ESP32 remote launcher is published in this repository.

### PowerShell diagnostic commands

```powershell
tailscale status
tailscale ip -4
ping -n 3 <ESP32_TAILSCALE_IP>
tailscale ping --icmp --c=3 <ESP32_TAILSCALE_IP>
tailscale ping --tsmp --c=3 <ESP32_TAILSCALE_IP>
Test-NetConnection <PROXMOX_TAILSCALE_IP> -Port 8006 -InformationLevel Quiet
```

These placeholders must be replaced with addresses from an authorized Tailnet. This is diagnostic evidence, not a claim that all ping modes must succeed for application UDP traffic to work.

## 5. Troubleshooting — connectivity probes vs application reachability

During external access testing, different Tailscale and ICMP probes produced different results:

| Diagnostic | Observed outcome | Interpretation |
| --- | --- | --- |
| Windows ICMP to ESP32 | 3/3 replies; 0% loss | IP reachability observed |
| ICMP round trip | 619–1806 ms; mean 1022 ms | High, variable observed latency |
| `tailscale ping --icmp` | At least one reply at 668 ms | ICMP works over the observed overlay path |
| `tailscale ping --tsmp` | Three timeouts | TSMP support/reply not established |
| Default `tailscale ping` | Timeouts in the tested setup | Not proof that application UDP/9999 is unreachable |
| Application wake-to-TCP test | Service became reachable | Functional integration demonstrated |

These probes use different protocol paths. The observed gateway relied on DERP-relayed traffic; direct peer-to-peer UDP was not validated.

See [Lab 06 — Troubleshooting and connectivity diagnostics](06-esp32-remote-wol-gateway.md#4-troubleshooting-and-connectivity-diagnostics) for the gateway-specific explanation, current firmware constraints and non-destructive alternatives.

## 6. Security boundaries and limitations

- Tailscale connectivity does not replace Proxmox login, Tailnet grants/ACLs, device access control or MFA.
- A dedicated policy/ACL and MFA hardening audit **has not been validated** by these acceptance tests.
- The ESP32 adaptation has an **open DERP TLS certificate authentication blocker** and command authorization issues; it is not a production-secure remote management component. See [Lab 06](06-esp32-remote-wol-gateway.md).
- The original acceptance tests in sections 4–5 did not include guest network validation. Section 8 records a later, limited guest SSH access extension. Neither establishes comprehensive guest networking, long-duration VPN/gateway reliability or production hardening.
- The [LAN Magic Packet sender](../scripts/Wake-Proxmox.ps1) and [ESP32/Tailscale remote sender](../scripts/Wake-Proxmox-VPN.ps1) are separate published workflows. The **31.7-second** result above comes from a controlled measurement procedure, not from a validated timing run of the current interactive launcher. See [wake diagnostics](WAKE-TESTING.md).

## 7. Related labs

- [Lab 01 — Installation & Host Setup](01-proxmox-installation.md)
- [Lab 02 — Linux Networking & Bridges](02-linux-networking.md)
- [Lab 04 — Wake-on-LAN & DKMS](04-wake-on-lan-alx-dkms.md)
- [Lab 05 — PowerShell LAN Wake Automation](05-powershell-wol-automation.md)
- [Lab 06 — ESP32 Remote Wake Gateway](06-esp32-remote-wol-gateway.md)
- [Architecture Overview](ARCHITECTURE.md)

**Result:** Authenticated remote Proxmox administration was functionally demonstrated from outside the home LAN. The ESP32-assisted wake-to-service integration also produced a measured successful result. Neither finding is a production security or endurance certification.

## 8. SSH access extension — November 2026

I extended the remote administration workflow with independent ED25519 client keys on Windows and Android (Termux), key-only SSH authentication and OpenSSH ProxyJump to Ubuntu guests. The guest firewall permits SSH from the jump host rather than individual workstation addresses. A temporary direct-client rule was removed after jump-host access was established.

```sshconfig
Host jump
    HostName <AUTHORIZED_HOST_ADDRESS>
    User <AUTHORIZED_HOST_ACCOUNT>
    IdentityFile ~/.ssh/id_ed25519_homelab
    IdentitiesOnly yes
Host guest
    HostName <GUEST_LAN_ADDRESS>
    User <GUEST_ACCOUNT>
    ProxyJump jump
    IdentityFile ~/.ssh/id_ed25519_homelab
    IdentitiesOnly yes
```

Illustrative configuration only; replace placeholders and provision a separate client key per device. The tested host uses an administrative account; a dedicated least-privilege jump account has not been implemented.

### Validation and troubleshooting

- Authenticated SSH to the host and both guests succeeded from a Windows client after key rotation, as recorded in the November closure. Earlier Android SSH access was recorded separately. A full post-rotation test across all clients and a separate off-LAN regression were not performed.
- The guest CLI inventories recorded the expected three client identities and revocation on both guests. Revocation on the host was confirmed by the operator.
- Guest firewall and effective SSH settings were inspected. The Cloud Platforms guest showed password, keyboard-interactive and root SSH login disabled, with public-key authentication enabled.
- Cloud-init logs recorded regeneration of SSH host keys following provisioning changes. The exact historical instance-ID transition was not captured. Subsequent connections and a guest fingerprint check indicated stability; extended reboot testing was not performed.

For a running guest, manage client access through the appropriate account's authorized_keys rather than repeatedly modifying its provisioning seed. When SSH warns that a host identity changed, verify the server fingerprint through a trusted console before removing the stale known_hosts entry. Do not disable strict host-key checking to work around the warning.

This is a functional SSH access extension, not a production security certification or a new numbered lab. Tailnet access-policy/MFA review and long-duration reliability remain outside this validation. These are documented historical results; no runtime tests were rerun for this documentation update.
