# Restart active network adapters
Get-NetAdapter |
Where-Object { $_.Status -eq 'Up' } |
ForEach-Object {
    try {
        Write-Output " - Restart: $($_.Name)"
        Restart-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Output "Failed: $($_.Name)"
    }
}