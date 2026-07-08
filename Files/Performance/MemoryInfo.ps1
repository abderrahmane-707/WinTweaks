param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Collect and report memory information
try {
    # Get OS memory counters and total physical RAM
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

    # Memory calculations (GB)
    $totalPhysicalGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
	
    # Convert free memory from KB to GB
    $freePhysicalGB = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
    $usedPhysicalGB = [math]::Round($totalPhysicalGB - $freePhysicalGB, 2)
    $memoryUsage = [math]::Round(($usedPhysicalGB / $totalPhysicalGB) * 100, 2)

    # Virtual Memory calculations (GB)
    $totalVirtualGB = [math]::Round(($os.TotalVirtualMemorySize * 1KB) / 1GB, 2)
    $freeVirtualGB = [math]::Round(($os.FreeVirtualMemory * 1KB) / 1GB, 2)

    # Memory overview
    Write-Log "Memory Information:"
    Write-Log " Total Memory:              $totalPhysicalGB GB"
    Write-Log " Used Memory:               $usedPhysicalGB GB"
    Write-Log " Free Memory:               $freePhysicalGB GB"
    Write-Log " Memory Usage:              $memoryUsage %"
    Write-Log " Virtual Memory: Max Size:  $totalVirtualGB GB"
    Write-Log " Virtual Memory: Available: $freeVirtualGB GB"

    # Per-slot details
    Write-Log "`nMemory Slots:"
    $memoryModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop

    if ($memoryModules) {
        foreach ($module in $memoryModules) {
            # Map SMBIOS memory type codes to names
            $memoryType = switch ($module.SMBIOSMemoryType) {
                20 { "DDR" }
                21 { "DDR2" }
                24 { "DDR3" }
                26 { "DDR4" }
                34 { "DDR5" }
                default { $module.SMBIOSMemoryType }
            }

            # Map form factor codes to descriptions
            $formFactor = switch ($module.FormFactor) {
                8  { "DIMM (Desktop)" }
                12 { "SODIMM (Laptop)" }
                default { $module.FormFactor }
            }

            Write-Log " Slot $($module.DeviceLocator):"
            Write-Log "  Manufacturer:  $($module.Manufacturer)"
            Write-Log "  Part Number:   $($module.PartNumber)"
            Write-Log "  Capacity:      $([math]::Round($module.Capacity / 1GB, 2)) GB"
            Write-Log "  Speed:         $($module.Speed) MHz"
            Write-Log "  Type:          $memoryType"
            Write-Log "  Form Factor:   $formFactor"
        }
    } else {
        Write-Log " No memory module information available"
    }

} catch {
    Write-Log " Error retrieving system information: $($_.Exception.Message)"
}