
# Wake-on-LAN Magic Packet sender for Windows PowerShell

param(
    [Parameter(Mandatory = $true)]
    [string]$MacAddress,

    [Parameter(Mandatory = $true)]
    [string]$BroadcastAddress,

    [int]$Port = 9,

    [string]$SourceIPAddress,

    [string]$TargetIPAddress,

    [int]$TargetPort = 8006,

    [switch]$OpenBrowser,

    [ValidateRange(1, 120)]
    [int]$MaxAttempts = 18,

    [ValidateRange(1, 60)]
    [int]$IntervalSeconds = 5
)

# Check whether the target is already reachable
if ($TargetIPAddress) {

    Write-Host "Checking server availability..."

    $isOnline = Test-NetConnection `
        -ComputerName $TargetIPAddress `
        -Port $TargetPort `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue

    if ($isOnline) {
        Write-Host "[OK] Server is already reachable on TCP port $TargetPort."
        $url = "https://${TargetIPAddress}:$TargetPort"
        Write-Host "Open Proxmox Web GUI: $url"
        if ($OpenBrowser) {
            Start-Process $url
        }
        exit 0
    }

    Write-Host "[INFO] Server is not reachable. Sending Wake-on-LAN packet..."
}

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


# Wait for the target service after sending the Magic Packet
if ($TargetIPAddress) {

    Write-Host "[INFO] Waiting for server availability..."

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {

        Start-Sleep -Seconds $intervalSeconds

        $isOnline = Test-NetConnection `
            -ComputerName $TargetIPAddress `
            -Port $TargetPort `
            -InformationLevel Quiet `
            -WarningAction SilentlyContinue

        if ($isOnline) {
            Write-Host "[SUCCESS] Server is reachable!"
            $url = "https://${TargetIPAddress}:$TargetPort"
            if ($OpenBrowser) {
                Start-Process $url
            }
            Write-Host "Open Proxmox Web GUI: $url"
            exit 0
        }

        Write-Host "[WAIT] Attempt $attempt of $maxAttempts..."
    }

    Write-Warning "Server did not become reachable after $maxAttempts checks."
    exit 1
}
# Successful completion when no target availability check was requested
exit 0
