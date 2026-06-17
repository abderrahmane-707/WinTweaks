Write-Host "Saved networks and their passwords"

# Extract value after a colon
function Get-ValueAfterColon {
    param ($TextLine)

    if ($null -eq $TextLine) { return $null }

    $parts = $TextLine.Split(":", 2)

    if ($parts.Count -lt 2) { return $null }

    return $parts[1].Trim().Replace('"','')
}

# Enumerate saved Wi-Fi profiles
$profiles = netsh wlan show profiles |
    Select-String "All User Profile" |
    ForEach-Object { $_.Line.Split(":", 2)[1].Trim() }

if (-not $profiles) {
    Write-Host "No Wi-Fi profiles found."
    exit
}

# Process each Wi-Fi profile
foreach ($profileName in $profiles) {

    $details = netsh wlan show profile name="$profileName" key=clear

    $ssid    = Get-ValueAfterColon ($details | Select-String "SSID name").Line
    $auth    = Get-ValueAfterColon ($details | Select-String "Authentication").Line
    $cipher  = Get-ValueAfterColon ($details | Select-String "Cipher").Line
    $keyLine = Get-ValueAfterColon ($details | Select-String "Key Content").Line

    # Retrieve password when available
    $password = if ($keyLine) {
        $keyLine
    }
    else {
        "Not available (Run as Admin?)"
    }

    # Display profile information
    Write-Host ""
    Write-Host "SSID:            $ssid"
    Write-Host " Authentication: $auth"
    Write-Host " Cipher:         $cipher"
    Write-Host " Password:       $password"
}