
# Wake-on-LAN Magic Packet sender for Windows PowerShell

param(
    [Parameter(Mandatory = $true)]
    [string]$MacAddress,

    [Parameter(Mandatory = $true)]
    [string]$BroadcastAddress,

    [int]$Port = 9,

    [string]$SourceIPAddress
)

# Convert the MAC address into 6 bytes
$macBytes = [byte[]](
    $MacAddress.Replace("-", ":").Split(":") |
    ForEach-Object {
        [Convert]::ToByte($_, 16)
    }
)

if ($macBytes.Length -ne 6) {
    throw "A MAC address must contain exactly 6 bytes."
}

# Build the 102-byte Magic Packet
$packet = [byte[]](
    (@([byte]0xFF) * 6) + ($macBytes * 16)
)

$udp = $null

try {
    # Optionally bind to a specific local network interface
    if ($SourceIPAddress) {
        $localEndpoint = [System.Net.IPEndPoint]::new(
            [System.Net.IPAddress]::Parse($SourceIPAddress),
            0
        )
        $udp = [System.Net.Sockets.UdpClient]::new($localEndpoint)
    }
    else {
        $udp = [System.Net.Sockets.UdpClient]::new()
    }

    $udp.EnableBroadcast = $true

    $sent = $udp.Send(
        $packet,
        $packet.Length,
        $BroadcastAddress,
        $Port
    )

    Write-Host "Magic Packet sent: $sent bytes"
    Write-Host "Target MAC: $MacAddress"
    Write-Host "Destination: ${BroadcastAddress}:$Port"
    Write-Host "Note: Sending does not confirm that the target powered on."
}
finally {
    if ($null -ne $udp) {
        $udp.Close()
    }
}
