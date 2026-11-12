# Interactive setup. Windows PowerShell 5.1, review candidate.
# Creates a machine-specific .cmd with strictly validated values.
$ErrorActionPreference = 'Stop'
$target = Join-Path $PSScriptRoot 'proxmox.local.cmd'

function Test-Value {
    param([string]$Name, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Name -eq 'LAN_MAC') {
        return $Value -match '^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'
    }
    if ($Name -in @('LAN_BROADCAST','PROXMOX_LAN_IP','ESP32_TS_IP','PROXMOX_TS_IP')) {
        $ip = $null
        return ($Value -match '^\d{1,3}(\.\d{1,3}){3}$' -and
            [System.Net.IPAddress]::TryParse($Value,[ref]$ip) -and
            $ip.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
    }
    if ($Name -in @('WAKE_UDP_PORT','TARGET_TCP_PORT')) {
        return ($Value -match '^\d{1,5}$' -and [int]$Value -ge 1 -and [int]$Value -le 65535)
    }
    if ($Name -eq 'MAX_PING_ATTEMPTS') {
        return ($Value -match '^\d{1,2}$' -and [int]$Value -ge 0 -and [int]$Value -le 20)
    }
    if ($Name -eq 'TCP_ATTEMPTS') {
        return ($Value -match '^\d{1,3}$' -and [int]$Value -ge 1 -and [int]$Value -le 120)
    }
    if ($Name -eq 'TCP_INTERVAL') {
        return ($Value -match '^\d{1,2}$' -and [int]$Value -ge 1 -and [int]$Value -le 60)
    }
    return $false
}

$existing = @{}
if (Test-Path -LiteralPath $target) {
    foreach ($line in (Get-Content -LiteralPath $target)) {
        if ($line -match '^set "([A-Z_]+)=(.*)"$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if (Test-Value $key $value) { $existing[$key] = $value }
        }
    }
}
$fields = @(
    @{Name='LAN_MAC'; Prompt='NIC MAC AA:BB:CC:DD:EE:FF'; Default=''},
    @{Name='LAN_BROADCAST'; Prompt='LAN broadcast IPv4'; Default=''},
    @{Name='PROXMOX_LAN_IP'; Prompt='Proxmox LAN IPv4'; Default=''},
    @{Name='ESP32_TS_IP'; Prompt='ESP32 Tailnet IPv4'; Default=''},
    @{Name='PROXMOX_TS_IP'; Prompt='Proxmox Tailnet IPv4'; Default=''},
    @{Name='WAKE_UDP_PORT'; Prompt='ESP32 UDP port'; Default='9999'},
    @{Name='TARGET_TCP_PORT'; Prompt='Proxmox TCP port'; Default='8006'},
    @{Name='MAX_PING_ATTEMPTS'; Prompt='Optional Tailscale ping checks (0=bypass)'; Default='0'},
    @{Name='TCP_ATTEMPTS'; Prompt='TCP check attempts'; Default='18'},
    @{Name='TCP_INTERVAL'; Prompt='TCP check interval in seconds'; Default='5'}
)
try {
    Write-Host 'Local configuration wizard. No Tailnet keys or passwords are requested.'
    Write-Host 'Press Enter to keep a displayed previous/default value.'
    $values = [ordered]@{}
    foreach ($field in $fields) {
        $key = $field.Name
        $fallback = [string]$field.Default
        if ($existing.ContainsKey($key)) { $fallback = [string]$existing[$key] }
        while ($true) {
            $label = [string]$field.Prompt
            if ($fallback) { $label += " [$fallback]" }
            $answer = Read-Host $label
            if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $fallback }
            if (Test-Value $key $answer) {
                $values[$key] = $answer
                break
            }
            Write-Warning "Invalid value for $key. Please try again."
        }
    }
    $lines = @('@echo off','rem Private local configuration - never commit.')
    foreach ($key in $values.Keys) { $lines += ('set "' + $key + '=' + $values[$key] + '"') }

    # Write temp first, then replace: incomplete input must not truncate existing settings.
    $temp = $target + '.tmp'
    [System.IO.File]::WriteAllLines($temp,[string[]]$lines,[System.Text.Encoding]::ASCII)
    Move-Item -LiteralPath $temp -Destination $target -Force
    Write-Host "Saved local settings to $target"
    exit 0
}
catch {
    Write-Warning ("Setup failed: " + $_.Exception.Message)
    exit 2
}
