# Windows Proxmox Launcher — LAN and ESP32 Remote Wake

> **Status:** Reference implementation reconstructed from recorded workflows. Windows PowerShell 5.1 runtime acceptance is required before this code can be described as the same tested local launcher.

## Workflows

| Menu option | Executed script | Network action |
| --- | --- | --- |
| Local wake | [`Wake-Proxmox.ps1`](Wake-Proxmox.ps1) | Standard 102-byte LAN Magic Packet by MAC/broadcast |
| Remote wake | [`Wake-Proxmox-VPN.ps1`](Wake-Proxmox-VPN.ps1) | UDP `wake\n` to ESP32 Tailnet peer at port `9999`, then TCP readiness polling |
| Configure | [`Setup-Proxmox.cmd`](Setup-Proxmox.cmd) and [`Setup-Proxmox.ps1`](Setup-Proxmox.ps1) | Validates IP, MAC, port, attempt and delay settings before writing local config |
| Quit | [`Start-Proxmox.cmd`](Start-Proxmox.cmd) | Ends the menu |

## Setup

1. Run [`Setup-Proxmox.cmd`](Setup-Proxmox.cmd) in Windows. Enter each value interactively; empty input preserves a displayed default or previously configured value.
2. Review the generated **gitignored** `scripts/proxmox.local.cmd`. Never publish that file.
3. Run [`Start-Proxmox.cmd`](Start-Proxmox.cmd) to select local or remote wake. It resolves scripts via `%~dp0`, so moving the repository does not require hardcoded drive letters.
4. For remote mode, install and sign in to Tailscale first, and ensure the ESP32 peer is registered. Use the [sample template](proxmox.local.example.cmd) only as a description of required fields; the addresses shown are non-routable documentation examples.

The configuration contains local addresses and the target MAC, but must **never** contain credentials or Tailscale auth keys. There is no requirement to edit Windows PowerShell's machine-wide execution policy. Review downloaded source files and local policy before running.

## Remote wake behavior

The remote workflow first checks whether the Proxmox TCP endpoint is already reachable. If not, it checks that the Tailscale backend reports `Running` and the configured ESP32 Tailnet IP appears in the current peer map.

A user-configurable `MAX_PING_ATTEMPTS` controls the optional default Tailscale ping preflight: **0 (default) skips it**, while 1–20 performs that many strict checks and aborts on repeated failure. DERP-only embedded gateways may not answer default DISCO probes even when application UDP works. **Bypassing ping does not bypass the mandatory Tailscale backend and peer-map checks.**

Once preflight passes, the client sends up to three unicast application requests. It expects ASCII `ok` from the configured ESP32 source endpoint, but independently polls TCP `8006` because **ACK is not proof of host boot**. An absent ACK also does not conclusively mean the Magic Packet was not sent.

Do **not** use the text `ping` over ESP32 UDP/9999 as a health check with current firmware: any received datagram may emit a WoL Magic Packet. See [Lab 06 troubleshooting](../docs/06-esp32-remote-wol-gateway.md#4-troubleshooting-and-connectivity-diagnostics).

## Exit codes and limitations

| Exit code | Remote workflow meaning |
| --- | --- |
| `0` | Target TCP endpoint reachable |
| `1` | Target TCP endpoint remained unavailable after polling |
| `2` | Tailscale prerequisite, peer map or ping preflight failed |
| `3` | Unexpected error |

TCP readiness is not complete system health or GUI authentication. The existing LAN sender has its own published exit-code contract.

**Safety:** Do not forward the ESP32 listener port to the public Internet. The ESP32 firmware's DERP TLS certificate verification and wake-command authorization are not production-hardened. Only use this workflow in an authorized controlled homelab.

## Verification required before merge

- [ ] Parse each new PowerShell script with Windows PowerShell 5.1.
- [ ] Test setup validation, editing existing settings, and moving the repository.
- [ ] Verify that real `scripts/proxmox.local.cmd` is ignored by Git.
- [ ] Check LAN sender from complete shutdown and when already online.
- [ ] Check remote sender with connected/disconnected Tailscale, missed UDP ACK and TCP timeout.
- [ ] Confirm Tailscale peer map handling and browser launch.
- [ ] Compare with the original local launcher code before treating this candidate as an archival implementation.
