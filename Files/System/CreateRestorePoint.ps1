try {
    # Enable System Restore on the C: drive
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
	Write-Output "System Restore enabled on C: drive"
} catch {
    # Handle failure
    $_.Exception.Message
    exit 1
}

try {
    # - RestorePointType: MODIFY_SETTINGS indicates settings were changed
    Checkpoint-Computer -Description "Hello world" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
	Write-Output "Restore point creation completed successfully"
    exit 0
} catch {
    # Handle restore point creation failure
    $_.Exception.Message
    exit 1
}