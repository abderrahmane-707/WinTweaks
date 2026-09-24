Write-Host "Windows Activation Status:"

try {
    # Fetch the active Windows license only (filter out Office/other product licenses
    # that may also have a non-null PartialProductKey)
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct `
        -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" `
        -ErrorAction Stop |
        Select-Object -First 1 LicenseStatus, RemainingGracePeriod, Description

    if ($null -eq $license) {
        Write-Host " Unable to retrieve activation status (No licensing info found)"
    }
    else {
        # LicenseStatus values per SoftwareLicensingProduct documentation:
        # 0 = Unlicensed, 1 = Licensed, 2 = OOBGrace, 3 = OOTGrace,
        # 4 = NonGenuineGrace, 5 = Notification (expired), 6 = ExtendedGrace
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
