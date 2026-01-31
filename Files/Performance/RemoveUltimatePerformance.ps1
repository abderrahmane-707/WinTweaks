$planName = "Ultimate Performance"
$balancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"

Write-Host " "
try {
    # 1. Find the target power plan
    $allPlans = powercfg /list
    $targetPlan = $allPlans | Select-String -Pattern "($planName|\($planName\))"

    if (-not $targetPlan) {
        Write-Host "Plan: '$planName' was not found. Nothing to delete."
        return
    }

    # Extract the GUID of the target plan
    $targetGUID = ([regex]::Match($targetPlan.Line, "[0-9a-fA-F-]{36}")).Value

    # 2. Switch to Balanced plan (cannot delete the active plan)
    Write-Host "Switching to Balanced power plan"
    powercfg /setactive $balancedGUID

    # 3. Delete the target plan
    Write-Host "Deleting $planName"
    powercfg /delete $targetGUID
}
catch {
    Write-Error "An error occurred during removal: $($_.Exception.Message)"
}