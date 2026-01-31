Write-Host "Saved networks and their passwords"
$profiles = netsh wlan show profiles |
    Select-String "All User Profile" |
    ForEach-Object {
        $_.Line.Split(":", 2)[1].Trim()
    }

if (-not $profiles) {
    Write-Host "No Wi-Fi profiles found."
    exit
}

foreach ($profileName in $profiles) {
	
    $details = netsh wlan show profile name="$profileName"
    function Get-ValueAfterColon {
        param ($TextLine)
        if ($null -eq $TextLine) { return "Unknown" }

        $parts = $TextLine.Split(":", 2)
        if ($parts.Count -lt 2) { return "Unknown" }

        return $parts[1].Trim().Replace('"','')
    }

    $line = ($details | Select-String "SSID name").Line
    Write-Host "`nSSID:  $(Get-ValueAfterColon $line)"

    $line = ($details | Select-String "Authentication").Line
    Write-Host " Encryption:  $(Get-ValueAfterColon $line)"
    $line = ($details | Select-String "Cipher").Line
    Write-Host " Authentication:  $(Get-ValueAfterColon $line)"

    $password = " Not available"
    try {
        $full = netsh wlan show profile name="$profileName" key=clear
        $line = ($full | Select-String "Key Content").Line
        $value = Get-ValueAfterColon $line
        if ($value -ne "Unknown") {
            $password = $value
        }
    } catch {
        $password = " Access denied"
    }

    Write-Host " Password:  $password"
}
