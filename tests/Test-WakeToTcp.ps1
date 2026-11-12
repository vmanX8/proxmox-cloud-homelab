# Reproducible trigger-to-first-observed-TCP test.
# Does not transmit wake traffic unless -SendWake is explicitly present.
# Windows PowerShell 5.1; reports first observed service readiness.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ProxmoxIPAddress,
  [string]$Esp32IPAddress,
  [ValidateRange(1,65535)][int]$TcpPort=8006,
  [ValidateRange(1,65535)][int]$UdpPort=9999,
  [ValidateRange(1,300)][int]$TimeoutSeconds=300,
  [ValidateRange(100,10000)][int]$PollIntervalMs=3000,
  [ValidateRange(100,10000)][int]$ConnectTimeoutMs=1500,
  [switch]$SendWake
)
$ErrorActionPreference='Stop'
function Assert-IPv4 {
    param([string]$Value)
    $ip=$null
    if($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or
       -not [System.Net.IPAddress]::TryParse($Value,[ref]$ip) -or
       $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw 'A literal IPv4 address is required.'
    }
}
function Test-TcpPort {
    param([string]$HostIp,[int]$Port,[int]$WaitMs)
    $client=New-Object System.Net.Sockets.TcpClient
    try {
        $async=$client.BeginConnect($HostIp,$Port,$null,$null)
        try {
            if(-not $async.AsyncWaitHandle.WaitOne($WaitMs,$false)) { return $false }
            try { $client.EndConnect($async); return $client.Connected } catch { return $false }
        }
        finally { $async.AsyncWaitHandle.Close() }
    }
    catch { return $false }
    finally { $client.Close() }
}
try {
    Assert-IPv4 $ProxmoxIPAddress
    if($SendWake) {
        if(-not $Esp32IPAddress) { throw '-Esp32IPAddress is required with -SendWake.' }
        Assert-IPv4 $Esp32IPAddress
    }
    Write-Host 'TCP readiness baseline...'
    if(Test-TcpPort $ProxmoxIPAddress $TcpPort $ConnectTimeoutMs) {
        Write-Warning 'Endpoint already reachable; no wake request will be sent.'
        exit 2
    }

    $clock=[System.Diagnostics.Stopwatch]::StartNew()
    $t0=[DateTimeOffset]::Now
    if($SendWake) {
        $udp=New-Object System.Net.Sockets.UdpClient
        try {
            $bytes=[System.Text.Encoding]::ASCII.GetBytes(('wake'+[char]10))
            [void]$udp.Send($bytes,$bytes.Length,$Esp32IPAddress,$UdpPort)
            Write-Host '[UDP SUBMITTED] One wake trigger; no remote ACK implied.'
        }
        finally { $udp.Close() }
    }
    else {
        Write-Host '[READ ONLY] No UDP transmitted; monitoring for externally initiated service readiness.'
    }
    Write-Host ('T0 (local clock): ' + $t0.ToString('o'))
    $deadline=[TimeSpan]::FromSeconds($TimeoutSeconds)
    while($clock.Elapsed -lt $deadline) {
        if(Test-TcpPort $ProxmoxIPAddress $TcpPort $ConnectTimeoutMs) {
            $t1=[DateTimeOffset]::Now
            $secs=[Math]::Round($clock.Elapsed.TotalSeconds,3)
            Write-Host ('T1 (local clock): ' + $t1.ToString('o'))
            Write-Host ("FIRST OBSERVED TCP READY after $secs seconds.")
            Write-Host 'TCP readiness is not physical boot causality or authenticated Web UI readiness.'
            exit 0
        }
        if($clock.Elapsed -ge $deadline) { break }
        Start-Sleep -Milliseconds $PollIntervalMs
    }
    Write-Warning "No TCP readiness observed within $TimeoutSeconds seconds."
    exit 1
}
catch {
    Write-Warning ("Measurement error: " + $_.Exception.Message)
    exit 3
}
