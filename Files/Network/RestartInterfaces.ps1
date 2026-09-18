param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    try {
        Write-Log " - Restarting adapter: $($_.Name)"
        Restart-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Log "   Failed to restart $($_.Name): $($_.Exception.Message)"
    }
}
