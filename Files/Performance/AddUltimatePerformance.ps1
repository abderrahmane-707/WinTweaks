# Official template GUID
$ultimateTemplateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$planName = "Ultimate Performance"

Write-Host " "
try {
    # 1. Check if the plan already exists
    $allPlans = powercfg /list
    $existingPlan = $allPlans | Select-String -Pattern "($planName|\($planName\))"

    if ($existingPlan) {
        # If it exists, extract its GUID and activate it
        $existingGUID = ([regex]::Match($existingPlan.Line, "[0-9a-fA-F-]{36}")).Value
        powercfg /setactive $existingGUID
        Write-Host "Plan: $planName already exists"
    }
    else {
        # 2. If it doesn't exist, duplicate the Ultimate Performance template
        $output = powercfg /duplicatescheme $ultimateTemplateGUID
        
        # Extract the new GUID
        $newGUID = ([regex]::Match($output, "[0-9a-fA-F-]{36}")).Value

        if ($newGUID) {
            # 3. Rename the plan and activate it
            powercfg /changename $newGUID "$planName"
            powercfg /setactive $newGUID
            
            Write-Host "Successfully added $planName and activated"
        } 
        else {
            throw "Could not create the plan"
        }
    }
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}