# Export all services start up
Get-Service | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Name),$($_.StartType)"
}