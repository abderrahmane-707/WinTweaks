Write-Host "Saved networks and their passwords"

# Retrieve all saved Wi-Fi profile names using netsh command
$profiles = netsh wlan show profiles |
    Select-String "All User Profile" |
    ForEach-Object {
        $_.Line.Split(":", 2)[1].Trim()
    }

# Check if any profiles were found
if (-not $profiles) {
    Write-Host "No Wi-Fi profiles found."
    exit
}

# Process each Wi-Fi profile
foreach ($profileName in $profiles) {
    
    # Get detailed information about the current profile
    $details = netsh wlan show profile name="$profileName"
    
    # Define helper function to extract values after colon in text lines
    function Get-ValueAfterColon {
        param ($TextLine)
        # Handle null input
        if ($null -eq $TextLine) { return "Unknown" }

        # Split on colon (max 2 parts) and return trimmed second part
        $parts = $TextLine.Split(":", 2)
        if ($parts.Count -lt 2) { return "Unknown" }

        return $parts[1].Trim().Replace('"','')
    }

    # Extract and display SSID name
    $line = ($details | Select-String "SSID name").Line
    Write-Host "`nSSID:  $(Get-ValueAfterColon $line)"

    # Extract and display encryption type (Note: The labels seem swapped in original code)
    $line = ($details | Select-String "Authentication").Line
    Write-Host " Encryption:  $(Get-ValueAfterColon $line)"
    
    # Extract and display authentication method
    $line = ($details | Select-String "Cipher").Line
    Write-Host " Authentication:  $(Get-ValueAfterColon $line)"

    # Attempt to retrieve password with clear text key
    $password = " Not available"
    try {
        # Get profile details including clear text key (requires admin privileges)
        $full = netsh wlan show profile name="$profileName" key=clear
        $line = ($full | Select-String "Key Content").Line
        $value = Get-ValueAfterColon $line
        
        # Check if password was actually found
        if ($value -ne "Unknown") {
            $password = $value
        }
    } catch {
        # Handle cases where password access is denied (insufficient permissions)
        $password = " Access denied"
    }

    # Display the password (or status message)
    Write-Host " Password:  $password"
}