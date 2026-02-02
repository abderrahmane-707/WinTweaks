try {
    # Attempt to enable System Restore feature on the C: drive
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
} catch {
    # Handle failure - System Restore might already be enabled or insufficient permissions
    Write-Error "Failed to enable System Restore on C: drive. Error: $($_.Exception.Message)"
    exit 1
}

try {
    # - RestorePointType: MODIFY_SETTINGS indicates settings were changed
    Checkpoint-Computer -Description "Hello world" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host "Restore point creation initiated"
} catch {
    # Handle restore point creation failure
    Write-Error "ERROR: Failed to create restore point. Error code: $($_.Exception.HResult) - $($_.Exception.Message)"
    exit 1
}

# Wait for 3 seconds to allow the system to complete restore point creation
Start-Sleep -Seconds 3

# Verify that the restore point was created successfully
try {
    # Get the most recent successful restore point
    $lastRestorePoint = Get-ComputerRestorePoint | 
        Where-Object {$_.LastStatus -eq "SUCCESS"} |  # Filter only successful restore points
        Select-Object -Last 1  # Get the most recent one
    
    # Check if the retrieved restore point matches our description
    if ($lastRestorePoint -and $lastRestorePoint.Description -eq "Hello world") {
        Write-Host "Restore point created successfully"
    } else {
        Write-Warning "Restore point creation verification failed"
    }
} catch {
    Write-Warning "Could not retrieve restore point information: $($_.Exception.Message)"
    exit 1
}