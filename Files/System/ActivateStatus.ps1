Write-Host "Windows Activation status:"
$lic = Get-CimInstance -Class SoftwareLicensingProduct | 
       Where-Object { $_.PartialProductKey } | 
       Select-Object -First 1

$xpr = cscript //nologo slmgr.vbs /xpr
    
if ($xpr -match 'permanently activated') {
    Write-Host $xpr
} else {
    Write-Host "Remaining Grace Period (hrs): $($lic.RemainingGracePeriod)"
    Write-Host $xpr
}