param (
    [Parameter(Mandatory=$true)]
    [string]$TargetDir
)

if (Test-Path $TargetDir) {
    
    # Calculate folder statistics safely
    $files = Get-ChildItem $TargetDir -Recurse -File
    
    if ($files) {
        $stats   = $files | Measure-Object -Property Length -Sum
        $count   = $stats.Count
        $sizeSum = $stats.Sum
    } else {
        $count   = 0
        $sizeSum = 0
    }

    # Convert sizes
    $sizeKB = [Math]::Round($sizeSum / 1KB, 2)
    $sizeMB = [Math]::Round($sizeSum / 1MB, 2)

    Write-Host "Folder path: $TargetDir"
    Write-Host " Size: $sizeKB KB ($sizeMB MB)"
    Write-Host " Files: $count"

    # Request confirmation for deletion
    choice /C YN /N /M "`nWARNING: Delete all data and backups files in this folder? (Y/N): "
    
    if ($LASTEXITCODE -eq 1) {
		Write-Host "Deleting: $TargetDir"
        Remove-Item -Path $TargetDir -Recurse -Force
    }

} else {
    Write-Host "${TargetDir}: Does not exist"
}