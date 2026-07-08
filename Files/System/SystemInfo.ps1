param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

Write-Log "System Information:"

try {
    # Single-pass CIM queries directly from the kernel — extremely fast
    $os   = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs   = Get-CimInstance -ClassName Win32_ComputerSystem
    $proc = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance -ClassName Win32_Bios
    $tz   = Get-CimInstance -ClassName Win32_TimeZone

    # Structured report output — memory section intentionally omitted as requested
    Write-Log "  Host Name:                 $($cs.Name)"
    Write-Log "  OS Name:                   $($os.Caption)"
    Write-Log "  OS Version:                $($os.Version)"
    Write-Log "  OS Manufacturer:           $($os.Manufacturer)"
    Write-Log "  Registered Owner:          $($os.RegisteredUser)"
    Write-Log "  Product ID:                $($os.SerialNumber)"
    Write-Log "  Original Install Date:     $($os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Log "  System Boot Time:          $($os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Log "  System Manufacturer:       $($cs.Manufacturer)"
    Write-Log "  System Model:              $($cs.Model)"
    Write-Log "  System Type:               $($cs.SystemType)"
    Write-Log "  Processor(s):              $($proc.Name)"
    Write-Log "  BIOS Version:              $($bios.SMBIOSBIOSVersion)"
    Write-Log "  System Directory:          $($os.SystemDirectory)"
    Write-Log "  System Locale:             $($os.MUILanguages -join ', ')"
    Write-Log "  Time Zone:                 $($tz.Description)"
}
catch {
    Write-Log "  Error retrieving system information: $_"
}