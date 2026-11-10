# Lab 05 — PowerShell Wake-on-LAN Automation

> **Status:** Functionally tested personal utility; not a production monitoring system.

## Motivation

A manually typed Wake-on-LAN Magic Packet command was inconvenient. The goal was to create a reusable Windows PowerShell utility with configurable parameters, an optional TCP availability check and predictable exit codes.

**Source:** [`scripts/Wake-Proxmox.ps1`](../scripts/Wake-Proxmox.ps1). The script is maintained in this repository; its source is not duplicated here.

## Implementation

- Accepts a target MAC, broadcast IPv4 destination, UDP port and optional source IP.
- Parses the MAC and builds a **102-byte Magic Packet**: six `FF` bytes followed by the MAC repeated sixteen times.
- Sends the packet using the .NET UDP client and releases the socket in a `finally` block.
- Optionally checks a target TCP endpoint before sending. If already reachable, wake is skipped.
- If wake is attempted, polls the TCP endpoint with bounded attempts and an interval.
- Optionally opens the HTTPS management URL in the Windows default browser.
- Uses explicit process exit codes: `0` for completed sender/success path, `1` if the configured TCP check times out.

## Verification observed

| Scenario | Observation |
|---|---|
| Full-shutdown LAN wake | Physical Toshiba host started and management UI became reachable |
| Already online | Script detected reachable TCP service without sending a second wake |
| Timeout / negative test | Unreachable test endpoint returned exit code `1` |
| Success regression | Correct `0` exit code following the prior stale-`LASTEXITCODE` fix |
| Optional browser open | Management UI opened in the browser |
| Local `.cmd` launcher | Tested twice from complete shutdown; launched PowerShell and reached the Web UI |

The batch launcher is kept **local only**: it contains Windows filesystem paths and machine-specific parameters. The repository provides the reusable script rather than a personal launcher.

## What the checks prove

A successful TCP connection to the configured service port confirms reachability **of that port at the time of testing**. It does not independently prove boot causality or full application health. When no target endpoint is provided, exit code `0` confirms that packet sending completed, not that the server woke.

## Areas for possible improvement

- Parameter input validation for MAC, IP and ports.
- Automated tests for exact Magic Packet bytes and success/failure branches.
- Less duplicated reachability logic if the script grows.

These are **improvement ideas**, not failed lab acceptance criteria. Remote wake over Tailscale is a different integration addressed in [Lab 06](06-esp32-remote-wol-gateway.md).

[Lab 04 — NIC driver and WoL support](04-wake-on-lan-alx-dkms.md) · [Architecture overview](ARCHITECTURE.md)
