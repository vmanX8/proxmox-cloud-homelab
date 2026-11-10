# Lab 03 — Tailscale VPN and Remote Access

> **Documentation status:** Draft for review against the completed HL-03 chat closure report.  
> **Implementation status:** HL-03 is recorded as completed in the project index; the original commands, screenshots and exact verification matrix have **not yet been transcribed into this document**.

## Scope

This lab concerns authenticated remote **management access** to the existing Proxmox host over a private overlay network. It is distinct from Wake-on-LAN, which powers on a machine that is shut down.

The purpose is to access the Proxmox management interface without exposing its administrative port to the public Internet.

## Architecture

```text
Remote client -- Tailscale private network -- Proxmox host (management UI)
```

The high-level design is documented in [the architecture overview](ARCHITECTURE.md).

## Evidence required before marking this document verified

The completed **HL-03 — Proxmox Tailscale VPN** closure report must be used to fill in the following facts without reproducing sensitive configuration:

1. Which devices ran Tailscale and which client/device initiated access.
2. The exact installation and enrolment steps actually performed.
3. Whether access was tested off-LAN (e.g. cellular/hotspot) and what was observed.
4. Which Proxmox service was accessed successfully and which transport/path was tested.
5. Any remote-shutdown test, if present in the closure report.
6. ACLs/grants, device approval, and permissions actually checked (rather than presumed).
7. Any troubleshooting and outstanding restrictions.

**Do not copy:** auth keys, real tailnet or device IP addresses, account identifiers, reusable secrets, device screenshots containing identifiers or raw logs.

## Verification vs assumptions

- **Reported by the project owner:** HL-03 implementation and closure are complete.
- **Not independently verified in this file:** specific authentication settings, exposure safeguards, remote-network test outputs and persistent post-reboot behaviour.
- **Not claimed:** an Internet-facing port-forward, a production-hardened VPN, or that Tailscale on a powered-off Proxmox host can wake that same host.

## Relationship to the other labs

- [Lab 02 — Linux Networking](02-linux-networking.md)
- [Lab 04 — Wake-on-LAN and DKMS](04-wake-on-lan-alx-dkms.md)
- [Lab 06 — ESP32 gateway](06-esp32-remote-wol-gateway.md) supplies a separately powered wake path.

**Review gate:** replace this evidence checklist with verified events from the HL-03 closure report before merging.
