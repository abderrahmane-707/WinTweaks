# Official template GUID for Ultimate Performance
$ultimateTemplateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$planName = "Ultimate Performance"

# Strict pattern to match an actual GUID, instead of any generic run of hex digits and dashes
$guidPattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

Write-Host ""
try {
    # Check if the plan already exists, using WMI instead of parsing powercfg /list text
    $existingPlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan -ErrorAction Stop |
        Where-Object { $_.ElementName -eq $planName } |
        Select-Object -First 1

    if ($existingPlan) {
        # If it exists, extract its GUID (strip the surrounding braces) and activate it
        $existingGUID = ($existingPlan.InstanceID.Split('\')[-1]) -replace '[{}]', ''

        powercfg /setactive $existingGUID
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to activate the existing plan (exit code: $LASTEXITCODE)"
        }

        Write-Host "Plan: $planName already exists and has been activated"
    }
    else {
        # If it doesn't exist, duplicate the Ultimate Performance template
        # (powercfg's text output still needs a regex here, since duplicatescheme has no CIM equivalent)
        $output = powercfg /duplicatescheme $ultimateTemplateGUID
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to duplicate the template (exit code: $LASTEXITCODE)"
        }

        # Extract the new GUID
        $newGUID = ([regex]::Match($output, $guidPattern)).Value

        if ($newGUID) {
            # Rename the plan and activate it
            powercfg /changename $newGUID "$planName"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to rename the plan (exit code: $LASTEXITCODE)"
            }

            powercfg /setactive $newGUID
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to activate the new plan (exit code: $LASTEXITCODE)"
            }

            Write-Host "Successfully added $planName and activated it"
        }
        else {
            throw "Could not create the plan: no new GUID found in the output"
        }
    }
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}
