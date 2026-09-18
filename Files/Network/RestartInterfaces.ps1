param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

$activeInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

# Check for active interfaces before proceeding
if (-not $activeInterfaces) {
    Write-Log "There are currently no active network interfaces"
    return
}

$activeInterfaces | ForEach-Object {
    try {
        Write-Log " - Restarting adapter: $($_.Name)"
        # Use InterfaceDescription instead of Name because it is more stable
        Restart-NetAdapter -InterfaceDescription $_.InterfaceDescription -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Log "   Failed to restart $($_.Name): $($_.Exception.Message)"
    }
}