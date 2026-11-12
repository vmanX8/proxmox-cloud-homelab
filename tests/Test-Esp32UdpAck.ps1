# Repeatable application-level ACK measurements.
# DANGER: each request can trigger a real WoL Magic Packet.
# Only run in an authorized environment with -AllowWakePackets.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Esp32IPAddress,
    [ValidateRange(1,65535)][int]$UdpPort=9999,
    [ValidateRange(1,40)][int]$Count=10,
    [ValidateRange(100,30000)][int]$AckTimeoutMs=8000,
    [ValidateRange(0,20000)][int]$DelayMs=1000,
    [switch]$AllowWakePackets
)
$ErrorActionPreference='Stop'
function Assert-IPv4 {
    param([string]$Value)
    $ip=$null
    if($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or
       -not [System.Net.IPAddress]::TryParse($Value,[ref]$ip) -or
       $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw 'Expected literal IPv4 address.'
    }
}
try {
    Assert-IPv4 $Esp32IPAddress
    if(-not $AllowWakePackets) {
        Write-Warning 'Refusing to transmit. -AllowWakePackets must be provided explicitly.'
        exit 2
    }
    Write-Warning "This test may broadcast a real LAN Magic Packet up to $Count times."
    $results=New-Object System.Collections.Generic.List[object]
    for($index=1;$index -le $Count;$index++) {
        $udp=New-Object System.Net.Sockets.UdpClient
        $watch=[System.Diagnostics.Stopwatch]::StartNew()
        $outcome='TIMEOUT'
        $srcPort=0
        $rtt=$null
        try {
            $udp.Connect($Esp32IPAddress,$UdpPort)
            $udp.Client.ReceiveTimeout=$AckTimeoutMs
            $srcPort=([System.Net.IPEndPoint]$udp.Client.LocalEndPoint).Port
            $payload=[System.Text.Encoding]::ASCII.GetBytes(('wake'+[char]10))
            [void]$udp.Send($payload,$payload.Length)
            $remote=[System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,0)
            try {
                $reply=$udp.Receive([ref]$remote)
                $received=[System.Text.Encoding]::ASCII.GetString($reply).Trim()
                if($remote.Address.ToString() -eq $Esp32IPAddress -and
                   $remote.Port -eq $UdpPort -and $received -eq 'ok') {
                    $outcome='ACK_OK'
                    $rtt=[Math]::Round($watch.Elapsed.TotalMilliseconds,1)
                }
                else {
                    $outcome='OTHER_REPLY'
                }
            }
            catch [System.Net.Sockets.SocketException] {
                if($_.Exception.SocketErrorCode -ne [System.Net.Sockets.SocketError]::TimedOut) { throw }
            }
        }
        finally { $udp.Close(); $watch.Stop() }
        $entry=[PSCustomObject]@{
            Test=$index
            SourcePort=$srcPort
            Result=$outcome
            RttMs=$rtt
            Timestamp=([DateTimeOffset]::Now).ToString('o')
        }
        [void]$results.Add($entry)
        $entry | Format-Table -AutoSize | Out-Host
        if($index -lt $Count -and $DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }
    $ok=@($results | Where-Object { $_.Result -eq 'ACK_OK' }).Count
    Write-Host ("ACK_OK: {0}/{1} ({2:N1}%)" -f $ok,$Count,(100*$ok/$Count))
    Write-Host 'ACK_OK means an application reply arrived, NOT verified physical boot.'
    Write-Host 'Use source ports and time offsets to correlate with ESP32 serial logs.'
    if($ok -eq $Count) { exit 0 }
    exit 1
}
catch {
    Write-Warning ("ACK test failed: " + $_.Exception.Message)
    exit 3
}
