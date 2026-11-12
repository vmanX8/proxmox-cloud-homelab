# Windows launcher verification and reusable network tests

> The utilities in `tests/` are **reconstructed test harnesses** based on observed acceptance procedures, not preserved original scripts or proof that this repository version has passed Windows hardware testing.

## Script catalog

| Script | Side effects | Purpose |
| --- | --- | --- |
| [`Test-PowerShellSyntax.ps1`](../tests/Test-PowerShellSyntax.ps1) | Read-only | Parse all checked-in PowerShell files using the Windows PowerShell AST parser |
| [`Test-TailscaleDiagnostics.ps1`](../tests/Test-TailscaleDiagnostics.ps1) | Read-only | ICMP reachability and optional TSMP/DISCO comparison without wake datagrams |
| [`Test-WakeToTcp.ps1`](../tests/Test-WakeToTcp.ps1) | Read-only by default | Time from test start to first observed TCP/8006 readiness; optional **one real UDP wake trigger** with `-SendWake` |
| [`Test-Esp32UdpAck.ps1`](../tests/Test-Esp32UdpAck.ps1) | **Sends real wake triggers** | Sample UDP `ok` ACK delivery/RTT/source-port correlation; requires `-AllowWakePackets` |
| [`Wake-Proxmox-VPN.ps1`](../scripts/Wake-Proxmox-VPN.ps1) | Sends real wake triggers | Operational ESP32/Tailscale launcher client with independent TCP polling |

All addresses shown below are **non-operational examples**. Substitute authorized Tailnet peers; do not commit real configuration.

## 1. PowerShell syntax validation

```powershell
.\tests\Test-PowerShellSyntax.ps1
```

**Expected:** every script reports PASS, exit code `0`. A failure means parsing should be fixed before runtime or network tests. This is a static syntax test only, not proof of correctness.

## 2. Tailscale connectivity diagnostics (read-only)

```powershell
.\tests\Test-TailscaleDiagnostics.ps1 -Esp32IPAddress "198.51.100.20" -Count 3
```

The default runs Windows ICMP and Tailscale ICMP without sending application traffic. Add `-IncludeDiscoDiagnostics` to include TSMP and default DISCO probes. Results do not prove the UDP/9999 listener will acknowledge a wake trigger. This script does not perform an application-level UDP ping, which would trigger WoL on the current firmware.

## 3. Non-destructive service-readiness observation

```powershell
.\tests\Test-WakeToTcp.ps1 -ProxmoxIPAddress "198.51.100.10" -TimeoutSeconds 300
```

No wake packet is transmitted without `-SendWake`. The script first checks the TCP baseline and returns code `2` if the service is already reachable. Otherwise, it observes until first TCP success or timeout.

For a **controlled, authorized actual wake**:

```powershell
.\tests\Test-WakeToTcp.ps1 -ProxmoxIPAddress "198.51.100.10" -Esp32IPAddress "198.51.100.20" -SendWake -TimeoutSeconds 300
```

One ASCII `wake\n` datagram is submitted to ESP32 UDP/9999 and the client polls Proxmox TCP/8006. Example controls: `-ConnectTimeoutMs 1500`, `-PollIntervalMs 3000`. Measured time is **trigger-to-first-observed-TCP success**, not necessarily exact boot time or full GUI health.

A previous physically separate integration test observed **31.7 seconds**; the test harness here is intended for reproduction, **not** a claim that it produced that historic result.

## 4. Application UDP ACK sample (destructive)

**Warning:** The current ESP32 listener treats **any** application UDP datagram as a wake command. Never use an application `ping` payload for health checking. Confirm the destination belongs to your own device before proceeding.

```powershell
.\tests\Test-Esp32UdpAck.ps1 -Esp32IPAddress "198.51.100.20" -Count 10 -AllowWakePackets
```

This runs 10 separate UDP wake requests and listens for the ESP32 `ok` ACK, with bounded receive timeout. It prints test number, source port, result, RTT and a timestamp, to assist cross-checking against device serial logs.

**Observed historical evidence** from separately run tests: 31/40 ACKs on the earlier firmware and 40/40 on the tested experimental DERP-only firmware. These numbers do **not** correspond to 40 physical computer boots or guarantee future delivery.

**Important distinction:** a sender's UDP send count, an ESP32 ACK and a live Proxmox HTTPS service measure *three different stages*.

## Recorded acceptance evidence (separate from these test harnesses)

The table below summarizes **observations recorded in the lab documentation**, not results obtained by executing the new scripts in this directory.

| Scenario | Recorded observation | What the test established |
| --- | --- | --- |
| LAN Magic Packet from shutdown | Toshiba powered on and Proxmox Web UI became accessible | Physical Wake-on-LAN worked on the tested NIC/driver |
| LAN sender while target was online | Server detected as reachable, no additional wake sent; exit code `0` | Already-online branch |
| Negative LAN sender test | Dummy MAC, unresponsive loopback TCP target on port `65534`, two polling attempts; exit code `1` | Bounded timeout/failure branch; not a proof of physical wake |
| PowerShell exit-code regression | Success path returned `0`, timeout path returned `1` | Correct process-level result reporting |
| Remote Tailscale access | Authenticated Proxmox dashboard from a remote laptop and mobile client | Application-level remote administration |
| ESP32-assisted wake-to-TCP sample | First observed TCP `8006` success **31.7 seconds** after one UDP trigger | Trigger-to-first-observed TCP readiness; physical shutdown not witnessed for that particular timed run |
| ESP32 application UDP ACK sampling | Earlier firmware **31/40**, experimental firmware **40/40**; experimental ACK RTT **498–893 ms**, mean approximately **603 ms** | Application responses over the tested transport; **not** 40 verified boots |
| Gateway diagnostics | Windows ICMP **3/3**, Tailscale ICMP reply observed; TSMP/default DISCO probes timed out | Different probe protocols have different outcomes; do not use default ping alone as an availability gate |

These results are described in [Lab 03](03-tailscale-vpn-remote-access.md), [Lab 05](05-powershell-wol-automation.md), [Lab 06](06-esp32-remote-wol-gateway.md) and [ESP32 firmware validation](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md).

**Evidence status:** The original ad-hoc PowerShell scripts for every historical measurement were not archived. The checked-in `tests/` commands are newly reconstructed reproducibility utilities. They must not be described as the exact executables that generated the recorded numbers.

### Additional negative-test example

The recorded LAN negative test used a dummy MAC and a local loopback TCP endpoint expected to be closed. A sanitized equivalent, when running on an authorized LAN, is:

```powershell
.\scripts\Wake-Proxmox.ps1 `
    -MacAddress "00:00:00:00:00:00" `
    -BroadcastAddress "<YOUR_LAN_BROADCAST>" `
    -TargetIPAddress "127.0.0.1" `
    -TargetPort 65534 `
    -MaxAttempts 2 `
    -IntervalSeconds 1
```

This example **still sends a real UDP broadcast** and should only be used on a network you control. The expected negative result (exit code `1`) assumes no service is listening on loopback port `65534`. Do not treat a negative result as a test of the actual server's power state.

## 5. Launcher: strict ping vs configurable bypass

The initial launcher revision used strict default Tailscale pings before sending. A failed default ping could prevent a working DERP-only gateway from receiving wake traffic.

The follow-up code exposes `MAX_PING_ATTEMPTS` as a local setting:

| Value | Behaviour |
| --- | --- |
| `0` (default) | Skip **optional** default Tailscale ping, but still check Tailscale backend and peer map |
| `1`–`20` | Run at most this many default pings; abort wake if none succeeds |

A default DISCO ping failure is **not** equivalent to UDP wake failure. For this experimental firmware, `0` is the practical setup choice; it is not a bypass for authentication or access controls. Keep ESP32 in an authorized Tailnet with appropriate grants/ACLs.

## 7. Windows acceptance matrix (not yet run on these PR versions)

| Scenario | Expected behaviour |
| --- | --- |
| Manual setup: example copied | `scripts/proxmox.local.cmd` exists with verified local values and remains Git-ignored |
| Manual setup: bad or placeholder values | Launcher rejects missing or `REPLACE_ME` required values; additional input validation should be reviewed |
| Repository moved to a different drive | The launcher still resolves scripts through `%~dp0` |
| Local launcher: host already online | No unnecessary packet; TCP endpoint reported |
| Local launcher: host shut down | LAN Magic Packet submitted and TCP polling eventually succeeds |
| Remote: backend stopped | Error code 2, no wake sent |
| Remote: ESP32 missing in peer map | Error code 2, no wake sent |
| Remote: `MAX_PING_ATTEMPTS=0` | Ping skipped; UDP and TCP checks continue |
| Remote: positive ping checks all fail | Error code 2 before UDP send |
| Remote: ACK lost, TCP eventually reachable | Successful TCP readiness, with warning about lost ACK |
| Remote: TCP times out | Error code 1, no false host-ready claim |
| ESP32 no access | Timeout, no successful ACK claim |
| No public config committed | `git check-ignore -v scripts/proxmox.local.cmd` should show ignore rule |

**Do not mark this matrix PASS without actual Windows runtime/hardware evidence.** No device flash, server change or test execution is part of these documentation PRs.

## Security and scope

The published Proxmox LAN sender remains unchanged. Do not forward TCP/8006 or ESP32 UDP/9999 to the public WAN. The ESP32's DERP TLS peer verification, authorization and endurance remain separate security/reliability blockers. See [Lab 06](06-esp32-remote-wol-gateway.md) and [the firmware validation report](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md).
