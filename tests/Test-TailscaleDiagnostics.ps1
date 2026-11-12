# Non-destructive Tailscale connectivity diagnostics for an ESP32 peer.
# Does NOT send UDP application traffic to port 9999.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Esp32IPAddress,
  [ValidateRange(1,10)][int]$Count=3,
  [switch]$IncludeDiscoDiagnostics
)
$ErrorActionPreference='Continue'
$ip=$null
if($Esp32IPAddress -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or
   -not [System.Net.IPAddress]::TryParse($Esp32IPAddress,[ref]$ip) -or
   $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    Write-Warning 'Provide a literal ESP32 IPv4 address.'
    exit 2
}
if(-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Warning 'Tailscale CLI not installed or not on PATH.'
    exit 2
}
Write-Host 'Tailscale status summary:'
& tailscale status
Write-Host 'Windows ICMP probes (non-destructive):'
& ping -n $Count $Esp32IPAddress
Write-Host 'Tailscale ICMP probes (non-destructive):'
& tailscale ping --icmp --c=$Count $Esp32IPAddress
if($IncludeDiscoDiagnostics) {
    Write-Host 'Optional TSMP probe:'
    & tailscale ping --tsmp --c=$Count $Esp32IPAddress
    Write-Host 'Optional default DISCO probe:'
    & tailscale ping --c=$Count $Esp32IPAddress
}
Write-Host 'Interpret probes separately. Failed DISCO/TSMP is not proof that the ESP32 UDP wake listener is offline.'
Write-Host 'No ESP32 UDP wake packets were sent by this script.'
exit 0
