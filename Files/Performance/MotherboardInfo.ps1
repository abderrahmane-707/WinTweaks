param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Formatted line (label: value) with uniform indentation
function Write-Field {
    param ([string]$Label, $Value, [int]$Indent = 2)
    Write-Log ((' ' * $Indent) + ("${Label}:").PadRight(28) + " $Value")
}

# Clean placeholder values written by some vendors in BIOS
function Convert-CleanString {
    param ($Value)
    $t = "$Value".Trim()
    if ($t -eq '') { return $null }
    if ($t -match '^(To Be Filled By O\.E\.M\.|Default string|None|N/A|Not Applicable|Not Specified|System Serial Number|System Product Name|System manufacturer|System Version|System SKUNumber|Asset Tag|Unknown|Undefined|0+)$') { return $null }
    return $t
}

function Get-OrNA {
    param ($Value)
    $c = Convert-CleanString $Value
    if ($null -eq $c) { return 'N/A' }
    return $c
}

# Chassis type per SMBIOS
function Get-ChassisText {
    param ($Codes)
    if (-not $Codes) { return 'N/A' }
    $map = @{
        1 = 'Other'; 2 = 'Unknown'; 3 = 'Desktop'; 4 = 'Low Profile Desktop'; 5 = 'Pizza Box'
        6 = 'Mini Tower'; 7 = 'Tower'; 8 = 'Portable'; 9 = 'Laptop'; 10 = 'Notebook'
        11 = 'Hand Held'; 12 = 'Docking Station'; 13 = 'All in One'; 14 = 'Sub Notebook'
        15 = 'Space-saving'; 16 = 'Lunch Box'; 17 = 'Main Server Chassis'; 23 = 'Rack Mount Chassis'
        24 = 'Sealed-case PC'; 30 = 'Tablet'; 31 = 'Convertible'; 32 = 'Detachable'
        33 = 'IoT Gateway'; 34 = 'Embedded PC'; 35 = 'Mini PC'; 36 = 'Stick PC'
    }
    $names = @($Codes | ForEach-Object {
        $c = [int]$_
        if ($map.ContainsKey($c)) { $map[$c] } else { "Code $c" }
    })
    return ($names -join ', ')
}

# Boot type: PEFirmwareType (1 = BIOS, 2 = UEFI) then SecureBoot key as fallback
function Get-FirmwareType {
    try {
        $t = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop).PEFirmwareType
        if ($t -eq 2) { return 'UEFI' }
        if ($t -eq 1) { return 'Legacy BIOS' }
    } catch { }

    # Fallback: kernel32!GetFirmwareType (Windows 8+): 1 = BIOS, 2 = UEFI
    try {
        if (-not ('FirmwareNative' -as [type])) {
            Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class FirmwareNative {
    [DllImport("kernel32.dll")]
    public static extern bool GetFirmwareType(ref uint FirmwareType);
}
'@
        }
        $ft = [uint32]0
        if ([FirmwareNative]::GetFirmwareType([ref]$ft)) {
            if ($ft -eq 2) { return 'UEFI' }
            if ($ft -eq 1) { return 'Legacy BIOS' }
        }
    } catch { }

    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State') { return 'UEFI' }
    return 'Unknown'
}

function Get-SecureBootStatus {
    param ([string]$FirmwareType)
    if ($FirmwareType -eq 'Legacy BIOS') { return 'Not supported (Legacy BIOS)' }
    try {
        $v = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction Stop).UEFISecureBootEnabled
        if ($v -eq 1) { return 'Enabled' } else { return 'Disabled' }
    } catch {
        return 'Not available'
    }
}

#  Data collection (each query in its own try block)
$board = $null; $cs = $null; $csp = $null; $enc = $null; $bios = $null; $cpu = $null

try { $board = Get-CimInstance Win32_BaseBoard -ErrorAction Stop | Select-Object -First 1 }
catch { Write-Log "Error accessing motherboard information: $($_.Exception.Message)" }

try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
catch { Write-Log "Error accessing computer system information: $($_.Exception.Message)" }

try { $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop | Select-Object -First 1 } catch { }
try { $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop | Select-Object -First 1 } catch { }

try { $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop | Select-Object -First 1 }
catch { Write-Log "Error accessing BIOS information: $($_.Exception.Message)" }

try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch { }

#  System identity
Write-Log "System Identity:"
if ($cs) {
    Write-Field 'Manufacturer'    (Get-OrNA $cs.Manufacturer)
    Write-Field 'Model'           (Get-OrNA $cs.Model)
    Write-Field 'Family'          (Get-OrNA $cs.SystemFamily)
    Write-Field 'SKU Number'      (Get-OrNA $cs.SystemSKUNumber)
} else {
    Write-Log "  No computer system information found."
}
if ($csp) {
    Write-Field 'Version'         (Get-OrNA $csp.Version)
    Write-Field 'System Serial'   (Get-OrNA $csp.IdentifyingNumber)
    Write-Field 'UUID'            (Get-OrNA $csp.UUID)
}
if ($enc) {
    Write-Field 'Chassis Type'    (Get-ChassisText $enc.ChassisTypes)
    Write-Field 'Asset Tag'       (Get-OrNA $enc.SMBIOSAssetTag)
}

#  Motherboard
Write-Log ""
Write-Log "Motherboard Information:"
if ($board) {
    Write-Field 'Manufacturer'    (Get-OrNA $board.Manufacturer)
    Write-Field 'Product/Model'   (Get-OrNA $board.Product)
    Write-Field 'Version'         (Get-OrNA $board.Version)
    Write-Field 'Board Serial'    (Get-OrNA $board.SerialNumber)

    # Semi-static logical properties are combined into one line (only enabled ones)
    $flags = @()
    if ($board.HostingBoard)          { $flags += 'Hosting Board' }
    if ($board.HotSwappable)          { $flags += 'Hot Swappable' }
    if ($board.Removable)             { $flags += 'Removable' }
    if ($board.Replaceable)           { $flags += 'Replaceable' }
    if ($board.RequiresDaughterBoard) { $flags += 'Requires Daughter Board' }
    Write-Field 'Board Properties' $(if ($flags.Count -gt 0) { $flags -join ', ' } else { '-' })
} else {
    Write-Log "  No motherboard information found."
}

#  Firmware (BIOS/UEFI)
Write-Log ""
Write-Log "Firmware/BIOS Information:"
$firmwareType = Get-FirmwareType
$secureBoot   = Get-SecureBootStatus $firmwareType
Write-Field 'Firmware Type' $firmwareType
Write-Field 'Secure Boot'   $secureBoot

if ($bios) {
    Write-Field 'BIOS Manufacturer' (Get-OrNA $bios.Manufacturer)
    Write-Field 'BIOS Name'         (Get-OrNA $bios.Name)

    # SMBIOSBIOSVersion is the version as shown in the BIOS screen, and may differ from Version
    $smbiosBiosVer = Get-OrNA $bios.SMBIOSBIOSVersion
    $biosVer       = Get-OrNA $bios.Version
    Write-Field 'BIOS Version' $smbiosBiosVer
    if ($biosVer -ne 'N/A' -and $biosVer -ne $smbiosBiosVer) {
        Write-Field 'BIOS Version (WMI)' $biosVer
    }

    $date = if ($bios.ReleaseDate -is [datetime]) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { 'N/A' }
    Write-Field 'BIOS Release Date' $date

    # BIOS serial number is shown only if it differs from the system serial
    $biosSerial = Convert-CleanString $bios.SerialNumber
    $sysSerial  = if ($csp) { Convert-CleanString $csp.IdentifyingNumber } else { $null }
    if ($biosSerial -and $biosSerial -ne $sysSerial) {
        Write-Field 'BIOS Serial' $biosSerial
    }

    if ($null -ne $bios.SMBIOSMajorVersion) {
        Write-Field 'SMBIOS Version' "$($bios.SMBIOSMajorVersion).$($bios.SMBIOSMinorVersion)"
    }

    # Embedded controller version (255 means not supported)
    if ($null -ne $bios.EmbeddedControllerMajorVersion -and $bios.EmbeddedControllerMajorVersion -ne 255) {
        Write-Field 'Embedded Controller' "$($bios.EmbeddedControllerMajorVersion).$($bios.EmbeddedControllerMinorVersion)"
    }
} else {
    Write-Log "  No BIOS information found."
}

#  Readiness: virtualization and TPM
Write-Log ""
Write-Log "Platform Readiness:"

if ($cpu) {
    Write-Field 'Virtualization (firmware)' $(if ($cpu.VirtualizationFirmwareEnabled) { 'Enabled' } else { 'Disabled / not reported' })
}
if ($cs -and $null -ne $cs.HypervisorPresent) {
    Write-Field 'Hypervisor Active' $(if ($cs.HypervisorPresent) { 'Yes' } else { 'No' })
}

# TPM
$tpmText = 'Not detected'
try {
    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop | Select-Object -First 1
    if ($tpm) {
        $spec = ("$($tpm.SpecVersion)" -split ',')[0].Trim()
        $tpmText = "Present, spec $spec"
    }
} catch { }
Write-Field 'TPM' $tpmText
