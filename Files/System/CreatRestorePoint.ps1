try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
} catch {
    Write-Error "Failed to enable System Restore on C: drive. Error: $($_.Exception.Message)"
    exit 1
}

try {
    Checkpoint-Computer -Description "Hello world" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host "Restore point creation initiated"
} catch {
    Write-Error "ERROR: Failed to create restore point. Error code: $($_.Exception.HResult) - $($_.Exception.Message)"
    exit 1
}

Start-Sleep -Seconds 5

try {
    $lastRestorePoint = Get-ComputerRestorePoint | 
        Where-Object {$_.LastStatus -eq "SUCCESS"} |
        Select-Object -Last 1
    
    if ($lastRestorePoint -and $lastRestorePoint.Description -eq "Hello world") {
        Write-Host "Restore point created successfully"
    } else {
        Write-Warning "Restore point creation verification failed"
    }
} catch {
    Write-Warning "Could not retrieve restore point information: $($_.Exception.Message)"
}