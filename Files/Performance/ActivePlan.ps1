# Get the current active power plan
$activePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive }

# Extract the name and GUID
if ($null -ne $activePlan) {
    $planName = $activePlan.ElementName
    $planGuid = $activePlan.InstanceID.Split('\')[-1]
} else {
    $planName = "Unknown"
    $planGuid = "Unknown"
}

# Display the result in a formatted layout
Write-Host "Current Power Plan:"
Write-Host " Name: $planName"
Write-Host " GUID: $planGuid"

