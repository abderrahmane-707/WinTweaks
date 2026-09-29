param (
    [Parameter(Position = 0)]
    [string]$PassedLogPath
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

. "$PSScriptRoot\..\Common\Logger.ps1"

$LogPath = $PassedLogPath

function Convert-ByteArrayToString {
    param([byte[]]$Bytes)
    return [System.Text.Encoding]::UTF8.GetString($Bytes).TrimEnd("`0")
}

# Extract value after a colon
function Get-ValueAfterColon {
    param ($TextLine)

    if ($null -eq $TextLine) { return $null }

    $parts = $TextLine.Split(":", 2)

    if ($parts.Count -lt 2) { return $null }

    return $parts[1].Trim().Replace('"','')
}

# Build a hashtable of ProfileName -> LastConnected (DateTime) from the registry
function Get-LastConnectedMap {
    $map  = @{}
    $base = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"

    if (-not (Test-Path $base)) { return $map }

    foreach ($key in Get-ChildItem $base) {
        try {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
        } catch { continue }

        if (-not $props.ProfileName -or -not $props.DateLastConnected) { continue }

        $bytes = $props.DateLastConnected
        if ($bytes.Length -lt 14) { continue }

        try {
            $dt = [datetime]::new(
                [BitConverter]::ToUInt16($bytes, 0),   # Year
                [BitConverter]::ToUInt16($bytes, 2),   # Month
                [BitConverter]::ToUInt16($bytes, 6),   # Day
                [BitConverter]::ToUInt16($bytes, 8),   # Hour
                [BitConverter]::ToUInt16($bytes, 10),  # Minute
                [BitConverter]::ToUInt16($bytes, 12)   # Second
            )
            $map[$props.ProfileName] = $dt
        } catch {
            # Ignore malformed entries
        }
    }

    return $map
}

Write-Log "Saved networks and their passwords:"

# Enumerate saved Wi-Fi profiles
$profiles = netsh wlan show profiles |
    Where-Object { $_ -match '^\s+[^:]+:\s+(.*)$' } |
    ForEach-Object { $matches[1].Trim() }

if (-not $profiles) {
    Write-Log "No Wi-Fi profiles found"
    exit
}

# Load last-connected times once (requires admin to read HKLM)
$lastConnectedMap = Get-LastConnectedMap

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

    # Retrieve last connection time from registry map
    $lastConnected = $null
    if ($ssid -and $lastConnectedMap.ContainsKey($ssid)) {
        $lastConnected = $lastConnectedMap[$ssid]
    }

    $lastConnectedStr = if ($lastConnected) {
        $lastConnected.ToString("yyyy-MM-dd HH:mm:ss")
    } else {
        "Unknown"
    }

    # Display and Log profile information
    Write-Log "`nSSID:            $ssid"
    Write-Log " Authentication: $auth"
    Write-Log " Cipher:         $cipher"
    Write-Log " Password:       $password"
    Write-Log " Last Connected: $lastConnectedStr"
}
