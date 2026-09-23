try {
    # Get the current active power plan
    $activePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -ErrorAction Stop |
        Where-Object { $_.IsActive }

    # Extract the name and GUID
    if ($null -ne $activePlan) {
        $planName = $activePlan.ElementName
        $planGuid = ($activePlan.InstanceID.Split('\')[-1]) -replace '[{}]', ''
    } else {
        $planName = "Unknown"
        $planGuid = "Unknown"
    }

    # Display the result in a formatted layout
    Write-Host "Current Power Plan:"
    Write-Host " Name: $planName"
    Write-Host " GUID: $planGuid"
}
catch {
    Write-Error "Failed to get the current power plan: $($_.Exception.Message)"
}
