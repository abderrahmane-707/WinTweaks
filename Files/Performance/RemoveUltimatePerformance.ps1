$planName = "Ultimate Performance"
$balancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"

Write-Host ""
try {
    # Find the target power plan using WMI instead of parsing powercfg /list text
    $targetPlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -ErrorAction Stop |
        Where-Object { $_.ElementName -eq $planName } |
        Select-Object -First 1

    if (-not $targetPlan) {
        Write-Host "Plan: '$planName' was not found. Nothing to delete"
        exit 1
    }

    # Extract the GUID of the target plan (strip the surrounding braces)
    $targetGUID = ($targetPlan.InstanceID.Split('\')[-1]) -replace '[{}]', ''

    # Check if the target plan is currently active (IsActive is a real boolean, no text parsing needed)
    $isActive = $targetPlan.IsActive

    if ($isActive) {
        # Switch to the Balanced plan (cannot delete the active plan), using a fixed GUID
        # instead of the plan's display name so this works regardless of the system's language
        Write-Host "Switching to Balanced power plan"
        powercfg /setactive $balancedGUID
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to switch to the Balanced plan (exit code: $LASTEXITCODE)"
        }
    }

    # Delete the target plan
    Write-Host "Deleting $planName"
    powercfg /delete $targetGUID
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete the plan (exit code: $LASTEXITCODE)"
    }

    Write-Host "Successfully deleted $planName"
}
catch {
    Write-Error "An error occurred during removal: $($_.Exception.Message)"
}
