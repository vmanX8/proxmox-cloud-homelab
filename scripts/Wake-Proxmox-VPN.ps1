# ESP32/Tailscale wake client (separate from LAN Magic Packet sender).
# Draft reconstructed from checkpoints; Windows PowerShell 5.1 runtime validation required.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Esp32IPAddress,
    [Parameter(Mandatory=$true)][string]$TargetIPAddress,
    [ValidateRange(1,65535)][int]$UdpPort=9999,
    [ValidateRange(1,65535)][int]$TargetPort=8006,
    [ValidateRange(1,120)][int]$MaxAttempts=18,
    [ValidateRange(1,60)][int]$IntervalSeconds=5,
    [switch]$OpenBrowser
)
$ErrorActionPreference='Stop'

function Assert-IPv4 {
    param([string]$Value)
    $ip=$null
    if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or
        -not [System.Net.IPAddress]::TryParse($Value,[ref]$ip) -or
        $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Expected an IPv4 literal: $Value"
    }
}
function Test-Tcp {
    param([string]$HostIp,[int]$Port,[int]$TimeoutMs=1500)
    $c=New-Object System.Net.Sockets.TcpClient
    try {
        $task=$c.BeginConnect($HostIp,$Port,$null,$null)
        try {
            if (-not $task.AsyncWaitHandle.WaitOne($TimeoutMs,$false)) { return $false }
            try { $c.EndConnect($task); return $c.Connected }
            catch { return $false }
        }
        finally { $task.AsyncWaitHandle.Close() }
    }
    catch { return $false }
    finally { $c.Close() }
}
function Show-Management {
    param([string]$HostIp,[int]$Port,[switch]$Launch)
    $url='https://' + $HostIp + ':' + $Port
    Write-Host "[TCP READY] $url"
    if ($Launch) { Start-Process $url }
}

try {
    Assert-IPv4 $Esp32IPAddress
    Assert-IPv4 $TargetIPAddress
    if (Test-Tcp $TargetIPAddress $TargetPort) {
        Write-Host '[INFO] Already reachable. No wake request needed.'
        Show-Management $TargetIPAddress $TargetPort -Launch:$OpenBrowser.IsPresent
        exit 0
    }
    if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
        Write-Warning 'Tailscale CLI not found.'
        exit 2
    }
    $statusOutput=& tailscale status --json 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'tailscale status --json failed' }
    $status=($statusOutput -join [Environment]::NewLine) | ConvertFrom-Json
    if ($status.BackendState -ne 'Running') {
        Write-Warning 'Tailscale backend is not Running.'
        exit 2
    }
    $found=$false
    if ($null -ne $status.Peer) {
        foreach ($peer in $status.Peer.PSObject.Properties) {
            if (@($peer.Value.TailscaleIPs) -contains $Esp32IPAddress) {
                $found=$true
                break
            }
        }
    }
    if (-not $found) {
        Write-Warning 'ESP32 absent from current Tailnet peer map.'
        exit 2
    }

    # Baseline V2: strict ping preflight may block a functional DERP-only ESP32.
    $pingOk=$false
    for($p=1;$p -le 3;$p++) {
        & tailscale ping --c=1 $Esp32IPAddress *> $null
        if($LASTEXITCODE -eq 0) { $pingOk=$true; break }
    }
    if(-not $pingOk) {
        Write-Warning 'Preflight ping failed; wake was not attempted.'
        exit 2
    }

    $udp=New-Object System.Net.Sockets.UdpClient
    $gotAck=$false
    try {
        # Connected UDP socket filters responses to configured peer/port.
        $udp.Connect($Esp32IPAddress,$UdpPort)
        $udp.Client.ReceiveTimeout=4000
        $bytes=[System.Text.Encoding]::ASCII.GetBytes(('wake'+[char]10))
        for($n=1;$n -le 3;$n++) {
            [void]$udp.Send($bytes,$bytes.Length)
            Write-Host "[UDP SENT] Attempt $n/3, waiting for optional ACK."
            $endpoint=New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any),0
            try {
                $reply=$udp.Receive([ref]$endpoint)
                if($endpoint.Address.ToString() -eq $Esp32IPAddress -and
                   $endpoint.Port -eq $UdpPort -and
                   [System.Text.Encoding]::ASCII.GetString($reply).Trim() -eq 'ok') {
                    $gotAck=$true
                    break
                }
            }
            catch [System.Net.Sockets.SocketException] {
                if($_.Exception.SocketErrorCode -ne [System.Net.Sockets.SocketError]::TimedOut) { throw }
            }
        }
    }
    finally { $udp.Close() }
    if($gotAck) { Write-Host '[ACK RECEIVED] ESP32 reported WoL submission, not boot.' }
    else { Write-Warning 'No ACK; target polling continues because ACK may be lost.' }

    for($i=1;$i -le $MaxAttempts;$i++) {
        if(Test-Tcp $TargetIPAddress $TargetPort) {
            Show-Management $TargetIPAddress $TargetPort -Launch:$OpenBrowser.IsPresent
            exit 0
        }
        Write-Host "[WAIT] TCP test $i/$MaxAttempts"
        if($i -lt $MaxAttempts) { Start-Sleep -Seconds $IntervalSeconds }
    }
    Write-Warning 'Proxmox TCP endpoint still unreachable after polling.'
    exit 1
}
catch {
    Write-Warning ("Remote wake error: " + $_.Exception.Message)
    exit 3
}
