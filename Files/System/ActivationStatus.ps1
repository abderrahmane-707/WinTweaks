Write-Host "Windows Activation Status:"

# Fetch the active license data using a direct CIM filter
$license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" | 
           Select-Object -First 1 LicenseStatus, RemainingGracePeriod, Description

if ($license.LicenseStatus -eq 1) {
    Write-Host " The machine is permanently activated" -ForegroundColor Green
} 
elseif ($license.LicenseStatus -eq 0) {
    Write-Host " The machine is not activated"
}
else {
    $remainingDays = [Math]::Round($license.RemainingGracePeriod / 1440, 2)
    Write-Host " Status: Grace Period (Not Permanently Activated)"
    Write-Host " Remaining Time: $remainingDays Days ($($license.RemainingGracePeriod) minutes)"
    Write-Host " Description: $($license.Description)"
}