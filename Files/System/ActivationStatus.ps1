Write-Host "Windows Activation Status:"

try {
    # Fetch the active Windows license by ApplicationId (Windows' fixed GUID) —
    # faster and more precise than 'Name LIKE Windows%'.
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct `
        -Filter "ApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" `
        -ErrorAction Stop |
        Select-Object -First 1 LicenseStatus, RemainingGracePeriod, Description

    if ($null -eq $license) {
        Write-Host " Unable to retrieve activation status (No licensing info found)"
    }
    else {
        switch ($license.LicenseStatus) {
            1 {
                Write-Host " The machine is permanently activated" -ForegroundColor Green
            }
            0 {
                Write-Host " The machine is not activated"
            }
            5 {
                Write-Host " Status: Notification (activation grace period has expired)"
                Write-Host " Description: $($license.Description)"
            }
            { $_ -in 2, 3, 4, 6 } {
                $remainingDays = [Math]::Round($license.RemainingGracePeriod / 1440, 2)
                Write-Host " Status: Grace Period (Not Permanently Activated)"
                Write-Host " Remaining Time: $remainingDays Days ($($license.RemainingGracePeriod) minutes)"
                Write-Host " Description: $($license.Description)"
            }
            default {
                Write-Host " Status: Unknown license status code ($($license.LicenseStatus))"
                Write-Host " Description: $($license.Description)"
            }
        }
    }
}
catch {
    Write-Error "Failed to retrieve Windows activation status: $($_.Exception.Message)"
}
