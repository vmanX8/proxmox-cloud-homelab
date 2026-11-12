# Windows Proxmox Launcher — LAN and Tailscale Remote Wake

> **Source:** synchronized with the final local launcher files supplied by the project owner. Previous GitHub launcher code was a reconstruction with incompatible configuration and parameter names. **Re-run the checks below against this published revision on Windows before claiming this exact revision was tested.**

## Two modes

| Option | Program | Action |
| --- | --- | --- |
| `L` — Local | [`Wake-Proxmox.ps1`](Wake-Proxmox.ps1) | If TCP is offline, send a 102-byte LAN WoL Magic Packet and poll TCP/8006 |
| `R` — Remote | [`Wake-Proxmox-VPN.ps1`](Wake-Proxmox-VPN.ps1) | Verify Tailscale and expected ESP32 peer, optionally probe it, submit UDP `wake\n` to ESP32/9999, retry ACK up to three times, poll Proxmox TCP/8006 |
| `Q` — Quit | [`Start-Proxmox.cmd`](Start-Proxmox.cmd) | Exit |

The ESP32 remotely receives an **application UDP trigger** and builds a separate LAN Magic Packet; the Windows remote script does not broadcast the LAN Magic Packet itself.

## Setup

1. Keep the `.cmd` and `.ps1` files together inside `scripts/`. The launcher resolves paths relative to its own location (`%~dp0`); moving the repository does not require changing absolute script paths.
2. Copy [`proxmox.local.example.cmd`](proxmox.local.example.cmd) to **`proxmox.local.cmd`** and replace all `REPLACE_ME` placeholders with local values. Do **not** rename the example itself.
3. For Remote, install Tailscale on the authorized Windows client and join the intended Tailnet. Configure the actual expected ESP32 `VPN_ESP32_HOSTNAME` and private Tailscale IP.
4. Run `Start-Proxmox.cmd`, choose `L` or `R`.
5. Keep `proxmox.local.cmd` private. This file is executed with Windows `CALL`; treat it as trusted executable configuration, never as an untrusted download.

### Configuration variables

| Variable | Usage |
| --- | --- |
| `PVE_MAC`, `LAN_BROADCAST`, `LAN_PVE_IP` | Local WoL target and LAN TCP readiness check |
| `LAN_SOURCE_IP` | Optional source NIC address |
| `VPN_ESP32_IP`, `VPN_PVE_IP` | ESP32 and Proxmox Tailnet endpoints |
| `VPN_ESP32_HOSTNAME` | Expected ESP32 Tailscale peer hostname, used together with its IP |
| `VPN_ESP32_PORT`, `TARGET_PORT` | Application trigger (default 9999), HTTPS TCP check (default 8006) |
| `MAX_PING_ATTEMPTS` | `0` = skip optional Tailscale ping; `1`–`5` = run strict attempts |
| `MAX_CHECK_ATTEMPTS`, `CHECK_INTERVAL_SECONDS` | TCP readiness polling count and interval |

For a DERP-only embedded client that does not answer default DISCO probes, set `MAX_PING_ATTEMPTS=0` in **your local** configuration. This skips *only* the optional ping gate: `tailscale status --json`, backend state and expected peer validation remain required. The example file retains the user's supplied default of `5`; edit the private copy to `0` when this is appropriate for the tested network.

## Source behavior and verification boundaries

The remote sender uses ASCII `wake\n` (**5 bytes**, not a 4-byte `wake` payload). An `ok` reply from the expected IP and UDP port means an application acknowledgment was received; it does not prove physical boot. Missing ACK does not necessarily mean WoL failed: the client continues independently checking TCP readiness.

The local utility similarly distinguishes Magic Packet submission from TCP readiness. TCP/8006 becoming reachable is not evidence of complete hypervisor health, guest readiness or successful GUI authentication.

**Do not use an application-level `ping` message on ESP32 UDP/9999:** the current firmware may treat any received UDP datagram as a wake request. Use ICMP diagnostics instead. No public UDP/9999 or TCP/8006 port-forward is recommended.

## Verification

On the actual Windows system:

```powershell
$files = @('.\scripts\Wake-Proxmox.ps1', '.\scripts\Wake-Proxmox-VPN.ps1')
foreach ($file in $files) {
    $tokens = $null; $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $file), [ref]$tokens, [ref]$parseErrors
    ) | Out-Null
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $parseErrors | Format-List
        throw "Parse failed: $file"
    }
    Write-Host "Parse OK: $file"
}
git check-ignore -v scripts/proxmox.local.cmd
git status --short
```

The historical recorded tests cover functional LAN wake, ESP32 remote wake, TCP service readiness and ping/ACK failure scenarios, but this GitHub revision has **not been executed on Windows by this documentation change**. See [Lab 05](../docs/05-powershell-wol-automation.md) and [Lab 06](../docs/06-esp32-remote-wol-gateway.md).

### Security and limitations

- Do not commit `proxmox.local.cmd`, Tailscale credentials or network identifiers. `.gitignore` does not remove already-tracked files or old Git history.
- Review downloaded scripts before execution. The launcher does not invoke `-ExecutionPolicy Bypass`; respect local and organizational execution policy.
- The ESP32 firmware still has DERP TLS verification and wake-command authorization concerns, as well as outstanding reliability tests. It is not production-ready.
- The separately proposed interactive setup wizard from the earlier reconstructed PR was removed: it used **different configuration variable names** and was not part of the supplied final launcher. Setup is currently the documented copy-and-edit workflow.
