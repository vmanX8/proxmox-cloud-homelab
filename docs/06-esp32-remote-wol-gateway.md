# Lab 06 — ESP32 Remote Wake-on-LAN Gateway

> **Status:** Two successful end-to-end power-on tests, with outstanding security and reliability work. **Not production-ready.**

## Why a separate wake gateway?

The Proxmox host cannot run its VPN software when fully shut down. An independently powered **ESP32-WROOM-32D** dev kit provides a wake path from a remote Tailscale client to a Magic Packet on the local Ethernet network.

```text
Android tablet (Tailscale)
       |
Tailscale relay / DERP (observed)
       |
ESP32-WROOM-32D (Wi-Fi, Tailscale application)
       |
UDP Magic Packet on local LAN
       |
Toshiba Ethernet adapter -> Proxmox boot -> Web UI
```

This is a **cross-repository integration lab**. The ESP32 firmware, its source history, license notices and full engineering documentation are maintained exclusively in [ESP32-WoL](https://github.com/vmanX8/ESP32-WoL).

## Verified end-to-end milestone

On **10 November 2026**, the adapted ESP32 firmware was built and flashed to the actual device. A remote Android Tailscale peer sent the UDP wake trigger to the ESP32, the Proxmox machine woke from a full shutdown, and the management UI became reachable. After another confirmed shutdown, this succeeded a second time.

The observed Tailscale communication path was **DERP relayed**. Direct peer-to-peer UDP/STUN was not validated. These tests establish that this **specific setup** completed two wake cycles, not that it is universally reliable or secure.

## Source ownership and attribution

- Original ESP32/Tailscale/WoL project: [medinajaime/esp32-wakeonlan](https://github.com/medinajaime/esp32-wakeonlan).
- Embedded WireGuard/lwIP component: [smartalock/wireguard-lwip](https://github.com/smartalock/wireguard-lwip).
- This project is a hardware integration and an **AI-assisted, tested adaptation**, not an original implementation of the Tailscale or WireGuard stacks.

[Upstream attribution and licenses](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/UPSTREAM_ATTRIBUTION.md) · [Source changes](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/CHANGES_FROM_UPSTREAM.md)

## Open security and reliability gates

1. **Security blocker:** The reviewed DERP TLS code still uses `MBEDTLS_SSL_VERIFY_NONE`; DERP server identity verification has not been established.
2. Wake-command authorization must be audited; use restrictive tailnet grants/ACLs and **never expose a public port-forward** for the wake listener.
3. Repeated reconnects, heap/stack use, long-term endurance, direct UDP and malformed-message handling require more tests.

Do not describe this as production-secure. Correcting these issues belongs to a future engineering/security lab with separate build and hardware validation.

## Further reading

- [ESP32 validated behaviour and limitations](https://github.com/vmanX8/ESP32-WoL/blob/main/docs/VALIDATION_AND_LIMITATIONS.md)
- [ESP32 firmware repository](https://github.com/vmanX8/ESP32-WoL)
- [Lab 03 — remote access](03-tailscale-vpn-remote-access.md)
- [Lab 04 — Ethernet WoL prerequisite](04-wake-on-lan-alx-dkms.md)
- [Architecture overview](ARCHITECTURE.md)
