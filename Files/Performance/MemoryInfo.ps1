try {
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
$computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
$totalPhysicalGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
$freePhysicalGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedPhysicalGB = [math]::Round($totalPhysicalGB - $freePhysicalGB, 2)
$memoryUsage = [math]::Round(($usedPhysicalGB / $totalPhysicalGB) * 100, 2)

Write-Host "Memory Information:"
Write-Host " Total Memory:  $totalPhysicalGB GB"
Write-Host " Used Memory:  $usedPhysicalGB GB"
Write-Host " Free Memory:  $freePhysicalGB GB"
Write-Host " Memory Usage:  $memoryUsage %"

Write-Host "`nMemory Slots:"
$memoryModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop
if ($memoryModules) {
  foreach ($module in $memoryModules) {

    $memoryType = switch ($module.SMBIOSMemoryType) {
      20 { "DDR" }
      21 { "DDR2" }
      24 { "DDR3" }
      26 { "DDR4" }
      34 { "DDR5" }
      default { $module.SMBIOSMemoryType }
    }

    $formFactor = switch ($module.FormFactor) {
      8 { "DIMM (Desktop)" }
      12 { "SODIMM (Laptop)" }
      default { $module.FormFactor }
    }

    Write-Host " Slot $($module.DeviceLocator):"
    Write-Host "  Manufacturer:  $($module.Manufacturer)"
    Write-Host "  Part Number:  $($module.PartNumber)"
    Write-Host "  Capacity:  $([math]::Round($module.Capacity / 1GB, 2)) GB"
    Write-Host "  Speed:  $($module.Speed) MHz"
    Write-Host "  Type:  $memoryType"
    Write-Host "  Form Factor:  $formFactor"
  }
}
else {
  Write-Host " No memory module information available"
}
} catch {
  Write-Host " Error retrieving system information: $($_.Exception.Message)"
}