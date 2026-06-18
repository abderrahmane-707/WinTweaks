# Get the current active power plan
$activePlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.IsActive }

# Extract the name and GUID
$planName = $activePlan.ElementName
$planGuid = $activePlan.InstanceID.Split('\')[-1]

# Display the result in a formatted layout
Write-Host "Current Power Plan:"
Write-Host " Name: $planName"
Write-Host " GUID: $planGuid"
