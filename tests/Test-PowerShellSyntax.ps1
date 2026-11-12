# Read-only PowerShell AST parsing check. CI runs this under PowerShell 7.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$paths=@(
  'scripts/Wake-Proxmox.ps1',
  'scripts/Wake-Proxmox-VPN.ps1',
  'tests/Test-WakeToTcp.ps1',
  'tests/Test-Esp32UdpAck.ps1',
  'tests/Test-TailscaleDiagnostics.ps1',
  'tests/Test-PowerShellSyntax.ps1'
)
$failed=$false
foreach($relative in $paths) {
    $path=Join-Path $root $relative
    $tokens=$null
    $parseErrors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,[ref]$tokens,[ref]$parseErrors
    )
    if($null -ne $parseErrors -and $parseErrors.Count -gt 0) {
        $failed=$true
        Write-Host ("[FAIL] " + $relative)
        foreach($err in $parseErrors) { Write-Warning $err.Message }
    }
    else {
        Write-Host ("[PASS] " + $relative)
    }
}
if($failed) { exit 1 }
exit 0
