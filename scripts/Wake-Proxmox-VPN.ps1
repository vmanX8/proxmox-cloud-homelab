# Tailscale VPN -> ESP32 UDP 'wake' -> Proxmox Web UI.
# PowerShell 5.1 compatible. The first successful DERP or direct pong is accepted.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Esp32IP,
    [Parameter(Mandatory = $true)]
    [string]$TargetIPAddress,
    [string]$Esp32HostName = 'esp32-pve-wol',
    [ValidateRange(1, 65535)]
    [int]$Esp32Port = 9999,
    [ValidateRange(1, 65535)]
    [int]$TargetPort = 8006,
    [switch]$OpenBrowser,
    [ValidateRange(0, 5)]
    [int]$MaxPingAttempts = 5,
    [ValidateRange(1, 30)]
    [int]$PingIntervalSeconds = 2,
    [ValidateRange(1, 120)]
    [int]$MaxAttempts = 18,
    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'
$webUrl = "https://${TargetIPAddress}:$TargetPort"

function Get-TailscaleExe {
    $command = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $defaultPath = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path -LiteralPath $defaultPath -PathType Leaf) { return $defaultPath }
    throw 'Tailscale CLI not found.'
}

function Test-TcpReady {
    param([string]$Address, [int]$Port, [int]$TimeoutMs = 2500)
    $client = New-Object System.Net.Sockets.TcpClient
    $result = $null
    try {
        $result = $client.BeginConnect($Address, $Port, $null, $null)
        if (-not $result.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($result)
        return $true
    }
    catch { return $false }
    finally {
        if ($null -ne $result) { $result.AsyncWaitHandle.Close() }
        $client.Close()
    }
}

function Test-ExpectedPeer {
    param([object]$Status, [string]$ExpectedIP, [string]$ExpectedName)
    if ($null -eq $Status.Peer) { return $false }
    foreach ($item in $Status.Peer.PSObject.Properties) {
        $peer = $item.Value
        if (($peer.TailscaleIPs -contains $ExpectedIP) -and ($peer.HostName -eq $ExpectedName)) {
            return $true
        }
    }
    return $false
}

function Open-ProxmoxBrowser {
    if ($OpenBrowser) { Start-Process $webUrl }
    Write-Host "Proxmox Web UI: $webUrl"
}

Write-Host '[INFO] Verifying Tailscale VPN and the expected ESP32 peer...'
try {
    $tailscaleExe = Get-TailscaleExe
    $statusJson = & $tailscaleExe status --json 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'tailscale status --json returned an error.' }
    $status = $statusJson | ConvertFrom-Json
    if ($status.BackendState -ne 'Running') {
        throw "VPN not connected (state: $($status.BackendState))."
    }
    if (-not (Test-ExpectedPeer -Status $status -ExpectedIP $Esp32IP -ExpectedName $Esp32HostName)) {
        throw "Expected peer $Esp32HostName ($Esp32IP) is not listed in this Tailnet."
    }
    Write-Host '[OK] Tailscale is connected and ESP32 peer is present.'
}
catch {
    Write-Host "[ERROR] VPN preflight failed: $($_.Exception.Message)"
    exit 2
}

Write-Host "[INFO] Checking Proxmox TCP $TargetPort..."
if (Test-TcpReady -Address $TargetIPAddress -Port $TargetPort) {
    Write-Host '[OK] Proxmox is already online. Wake not needed.'
    Open-ProxmoxBrowser
    exit 0
}

if ($MaxPingAttempts -eq 0) {
    Write-Host '[INFO] MaxPingAttempts is 0. Bypassing ESP32 ping test and forcing execution...'
    $ready = $true
} else {
    $ready = $false
    for ($attempt = 1; $attempt -le $MaxPingAttempts; $attempt++) {
        Write-Host "[PING] Checking ESP32 $attempt/$MaxPingAttempts..."
        try {
            $pingResult = & $tailscaleExe ping --c=1 --until-direct=false --timeout=5s $Esp32IP 2>&1 | Out-String
            if (($LASTEXITCODE -eq 0) -and ($pingResult -match '(?im)^\s*pong from\s+')) {
                Write-Host '[OK] ESP32 replied over Tailscale (direct or DERP).'
                $ready = $true
                break
            }
        }
        catch { Write-Host "[WARN] Tailscale ping: $($_.Exception.Message)" }
        if ($attempt -lt $MaxPingAttempts) { Start-Sleep -Seconds $PingIntervalSeconds }
    }
}

if (-not $ready) {
    Write-Host '[ERROR] ESP32 did not reply to five-or-fewer pings. Wake not sent.'
    exit 3
}

# UDP wake with application-level ACK and bounded retries.
# PowerShell 5.1 compatible.

$payload = [System.Text.Encoding]::ASCII.GetBytes("wake`n")
$udp = [System.Net.Sockets.UdpClient]::new(0)
$udp.Client.ReceiveTimeout = 4000

$ackReceived = $false
$sentAtLeastOnce = $false

try {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "[WAKE] Attempt $attempt/3"

        try {
            $sent = $udp.Send(
                $payload, $payload.Length,
                $Esp32IP, $Esp32Port
            )

            if ($sent -ne $payload.Length) {
                throw "Incomplete UDP send: $sent bytes"
            }

            $sentAtLeastOnce = $true

            $remote = [System.Net.IPEndPoint]::new(
                [System.Net.IPAddress]::Any, 0
            )

            $reply = $udp.Receive([ref]$remote)
            $message = [System.Text.Encoding]::ASCII.GetString($reply)

            if ($message -eq "ok" -and
                $remote.Address.ToString() -eq $Esp32IP -and
                $remote.Port -eq $Esp32Port) {

                Write-Host "[OK] ESP32 acknowledged wake request."
                $ackReceived = $true
                break
            }

            Write-Host "[WARN] Unexpected UDP reply."
        }
        catch {
            Write-Host "[WARN] Attempt $attempt failed: $($_.Exception.Message)"
        }
    }
}
finally {
    $udp.Close()
}

if (-not $sentAtLeastOnce) {
    Write-Host "[ERROR] All UDP sends failed."
    exit 4
}

if (-not $ackReceived) {
    Write-Host "[WARN] No ESP32 ACK. Checking Proxmox anyway."
}

# Continue with the existing TCP readiness loop.

$watch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "[INFO] Waiting for Proxmox: max $MaxAttempts checks, every $IntervalSeconds seconds."
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Start-Sleep -Seconds $IntervalSeconds
    if (Test-TcpReady -Address $TargetIPAddress -Port $TargetPort) {
        $watch.Stop()
        Write-Host ('[SUCCESS] Proxmox port ready after {0:N1}s.' -f $watch.Elapsed.TotalSeconds)
        Open-ProxmoxBrowser
        exit 0
    }
    Write-Host "[WAIT] Check $attempt/$MaxAttempts"
}
$watch.Stop()
Write-Host '[ERROR] Proxmox did not become reachable in the check window.'
exit 1
