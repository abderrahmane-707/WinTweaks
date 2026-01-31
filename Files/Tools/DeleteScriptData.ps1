$path = "C:\ProgramData\Win_Tweaks"

if (Test-Path $path) {
	
    # Calculate folder statistics
    $stats = Get-ChildItem $path -Recurse -File | Measure-Object -Property Length -Sum
    $count = $stats.Count
    $sizeKB = [Math]::Round($stats.Sum / 1KB, 2)

    Write-Host "Folder path: $path"
    Write-Host " Size: $sizeKB KB"
    Write-Host " Files: $count"

    # Request confirmation for deletion
    Write-Host ""
    choice /C YN /N /M "Delete all data and backups files in Win_Tweaks folder? (Y/N): "
    
    if ($LASTEXITCODE -eq 1) {
        Remove-Item -Path $path -Recurse -Force
        Write-Host " All data has been deleted"
    }

} else {
    Write-Host "The folder does not exist"
}