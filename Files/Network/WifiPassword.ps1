param (
    [string]$PassedLogPath
)

$LogPath = $PassedLogPath

function Write-Log {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogPath -Value $Message -Encoding utf8
}

function Convert-ByteArrayToString {
    param([byte[]]$Bytes)
    return [System.Text.Encoding]::ASCII.GetString($Bytes).TrimEnd("`0")
}

# Extract value after a colon
function Get-ValueAfterColon {
    param ($TextLine)

    if ($null -eq $TextLine) { return $null }

    $parts = $TextLine.Split(":", 2)

    if ($parts.Count -lt 2) { return $null }

    return $parts[1].Trim().Replace('"','')
}

Write-Log "Saved networks and their passwords"

# Enumerate saved Wi-Fi profiles
$profiles = netsh wlan show profiles |
    Select-String "All User Profile" |
    ForEach-Object { $_.Line.Split(":", 2)[1].Trim() }

if (-not $profiles) {
    Write-Log "No Wi-Fi profiles found"
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
        "Not available"
    }

    # Display and Log profile information
    Write-Log "`nSSID:            $ssid"
    Write-Log " Authentication: $auth"
    Write-Log " Cipher:         $cipher"
    Write-Log " Password:       $password"
}
