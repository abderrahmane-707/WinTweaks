foreach ($f in @(
    "MicrosoftWindowsPowerShellV2"        # Legacy PowerShell version
    "MicrosoftWindowsPowerShellV2Root"    # Root components for PowerShell 2.0
    "SMB1Protocol"                        # Old file sharing protocol (vulnerable)
    "SmbDirect"                           # Remote Direct Memory Access for SMB
    "TFTP"                                # Trivial File Transfer Protocol
    "TelnetClient"                        # Unencrypted remote login client
    "WCF-TCP-PortSharing45"               # .NET Framework 4.5 TCP Port Sharing
)) {
    $info = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue

    if (-not $info) {
        Write-Output "Feature '$f' not found"
        continue
    }

    if ($info.State -eq 'Enabled') {
        Write-Output "Disabling: $f"
        Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart
    }
    else {
        Write-Output "Feature '$f' is already disabled"
    }
}