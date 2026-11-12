# Local Wake-on-LAN Magic Packet sender for Windows
# Maintains the original flow: check TCP -> send Magic Packet -> poll TCP -> open GUI.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MacAddress,
    [Parameter(Mandatory = $true)]
    [string]$BroadcastAddress,
    [ValidateRange(1, 65535)]
    [int]$Port = 9,
    [string]$SourceIPAddress = '',
    [Parameter(Mandatory = $true)]
    [string]$TargetIPAddress,
    [ValidateRange(1, 65535)]
    [int]$TargetPort = 8006,
    [switch]$OpenBrowser,
    [ValidateRange(1, 120)]
    [int]$MaxAttempts = 18,
    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'
$webUrl = "https://${TargetIPAddress}:$TargetPort"

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

function Open-ProxmoxBrowser {
    if ($OpenBrowser) { Start-Process $webUrl }
    Write-Host "Proxmox Web UI: $webUrl"
}

Write-Host '[INFO] Checking LAN Proxmox availability...'
if (Test-TcpReady -Address $TargetIPAddress -Port $TargetPort) {
    Write-Host '[OK] Proxmox is already reachable. No Magic Packet needed.'
    Open-ProxmoxBrowser
    exit 0
}

try {
    $parts = $MacAddress.Replace('-', ':').Split(':')
    if ($parts.Length -ne 6) { throw 'MAC must have exactly 6 hexadecimal octets.' }
    $macBytes = [byte[]]($parts | ForEach-Object { [Convert]::ToByte($_, 16) })
    $packet = [byte[]]((@([byte]0xFF) * 6) + ($macBytes * 16))
    if ($packet.Length -ne 102) { throw 'Magic Packet length is not 102 bytes.' }

    $udp = $null
    try {
        if ($SourceIPAddress) {
            $endpoint = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Parse($SourceIPAddress), 0)
            $udp = [System.Net.Sockets.UdpClient]::new($endpoint)
        }
        else {
            $udp = New-Object System.Net.Sockets.UdpClient
        }
        $udp.EnableBroadcast = $true
        $sent = $udp.Send($packet, $packet.Length, $BroadcastAddress, $Port)
        if ($sent -ne 102) { throw "Unexpected UDP send byte count: $sent" }
        Write-Host "[INFO] Sent $sent bytes to ${BroadcastAddress}:$Port (not proof of wake)."
    }
    finally {
        if ($null -ne $udp) { $udp.Close() }
    }
}
catch {
    Write-Host "[ERROR] Local Magic Packet failed: $($_.Exception.Message)"
    exit 4
}

Write-Host "[INFO] Waiting for Proxmox: max $MaxAttempts checks, every $IntervalSeconds seconds."
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    Start-Sleep -Seconds $IntervalSeconds
    if (Test-TcpReady -Address $TargetIPAddress -Port $TargetPort) {
        Write-Host '[SUCCESS] Proxmox TCP port is reachable.'
        Open-ProxmoxBrowser
        exit 0
    }
    Write-Host "[WAIT] Check $attempt/$MaxAttempts"
}
Write-Host '[ERROR] Timed out waiting for the Proxmox Web UI.'
exit 1
