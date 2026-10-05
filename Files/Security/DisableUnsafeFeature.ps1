param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

$features = @(
    "MicrosoftWindowsPowerShellV2"        # Legacy PowerShell version
    "MicrosoftWindowsPowerShellV2Root"    # Root components for PowerShell 2.0
    "SMB1Protocol"                        # Old file sharing protocol (vulnerable)
    "SmbDirect"                           # Remote Direct Memory Access for SMB
    "TFTP"                                # Trivial File Transfer Protocol
    "TelnetClient"                        # Unencrypted remote login client
    "WCF-TCP-PortSharing45"               # .NET Framework 4.5 TCP Port Sharing
)

$state = @{}
try {
    Get-WindowsOptionalFeature -Online -ErrorAction Stop |
        Where-Object { $_.FeatureName -in $features } |
        ForEach-Object { $state[$_.FeatureName] = $_.State }
}
catch {
    Write-Log "Error querying optional features: $($_.Exception.Message)"
    return
}

Write-Log "Optional Features Hardening:"

foreach ($f in $features) {
    if (-not $state.ContainsKey($f)) {
        Write-Log "  '$f' not found"
        continue
    }

    if ($state[$f] -ne 'Enabled') {
        Write-Log "  '$f' is already disabled"
        continue
    }

    Write-Log "  Disabling: $f"
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Log "  Failed to disable '${f}': $($_.Exception.Message)"
    }
}
