# Receive log path from calling batch file (must be first statement)
param (
    [string]$PassedLogPath
)

# Use supplied path directly
$LogPath = $PassedLogPath

# Write output to console and log file (UTF-8)
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogPath -Value $Message -Encoding utf8
}

# Motherboard information
Write-Log "`nMotherboard Information:"
try {
    # Modern CIM-based retrieval (replaces deprecated Get-WmiObject)
    $motherboard = Get-CimInstance Win32_BaseBoard -ErrorAction Stop

    if ($motherboard) {
        Write-Log " Manufacturer:   $($motherboard.Manufacturer)"
        Write-Log " Product/Model:  $($motherboard.Product)"
        Write-Log " Version:        $($motherboard.Version)"
        Write-Log " Serial Number:  $($motherboard.SerialNumber)"

        Write-Log " Hosting Board:  $($motherboard.HostingBoard)"
        Write-Log " Hot Swappable:  $($motherboard.HotSwappable)"
        Write-Log " Removable:      $($motherboard.Removable)"
        Write-Log " Replaceable:    $($motherboard.Replaceable)"
        Write-Log " Requires Daughter Board:  $($motherboard.RequiresDaughterBoard)"
    } else {
        Write-Log " No motherboard information found."
    }
} catch {
    Write-Log " Error accessing motherboard information: $($_.Exception.Message)"
}

# Firmware type detection (UEFI vs Legacy BIOS)
Write-Log "`nFirmware/BIOS Information:"
try {
    # SecureBoot registry key exists only on UEFI systems
    if (Test-Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State") {
        $firmwareType = "UEFI"
    } else {
        $firmwareType = "Legacy BIOS"
    }
    Write-Log " Firmware Type:  $firmwareType"
} catch {
    Write-Log " Firmware Type:  Could not determine"
}

# BIOS details
try {
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop

    if ($bios) {
        Write-Log " BIOS Manufacturer:   $($bios.Manufacturer)"
        Write-Log " BIOS Name:           $($bios.Name)"
        Write-Log " BIOS Version:        $($bios.Version)"
        Write-Log " BIOS Serial Number:  $($bios.SerialNumber)"
        Write-Log " BIOS Release Date:   $($bios.ReleaseDate)"
    }
} catch {
    Write-Log " Error accessing BIOS information: $($_.Exception.Message)"
}

# SMBIOS information
Write-Log "`nSMBIOS Information:"
try {
    $smbios = Get-CimInstance Win32_SMBIOSMemory -ErrorAction SilentlyContinue

    if ($smbios) {
        # Read raw SMBIOS tables via CIM (root\wmi namespace)
        $smbiosData = Get-CimInstance -Namespace root\wmi -ClassName MSSmBios_RawSMBiosTables -ErrorAction SilentlyContinue

        if ($smbiosData) {
            $smbiosVersion = "$($smbiosData.SmbiosMajorVersion).$($smbiosData.SmbiosMinorVersion)"
            Write-Log " SMBIOS Version:      $smbiosVersion"
            Write-Log " SMBIOS Data Length:  $($smbiosData.Size) bytes"
        }
    } else {
        Write-Log " SMBIOS information not available on this system."
    }
} catch {
    Write-Log " SMBIOS detailed information error: $($_.Exception.Message)"
}