try {
    # Get operating system information including memory statistics
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    
    # Get computer system information including total physical memory
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    
    # Calculate memory statistics:
    # Total physical memory in GB (converted from bytes, rounded to 2 decimal places)
    $totalPhysicalGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
    
    # Free physical memory in GB (converted from KB to MB to GB, rounded)
    $freePhysicalGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    
    # Calculate used memory by subtracting free from total
    $usedPhysicalGB = [math]::Round($totalPhysicalGB - $freePhysicalGB, 2)
    
    # Calculate memory usage percentage (used divided by total, multiplied by 100)
    $memoryUsage = [math]::Round(($usedPhysicalGB / $totalPhysicalGB) * 100, 2)

    # Display memory overview information
    Write-Host "Memory Information:"
    Write-Host " Total Memory:  $totalPhysicalGB GB"
    Write-Host " Used Memory:  $usedPhysicalGB GB"
    Write-Host " Free Memory:  $freePhysicalGB GB"
    Write-Host " Memory Usage:  $memoryUsage %"

    # Display detailed information about individual memory modules (RAM sticks)
    Write-Host "`nMemory Slots:"
    $memoryModules = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop
    
    if ($memoryModules) {
        # Process each memory module (RAM stick) found in the system
        foreach ($module in $memoryModules) {
            # Convert SMBIOS memory type codes to human-readable format
            $memoryType = switch ($module.SMBIOSMemoryType) {
                20 { "DDR" }
                21 { "DDR2" }
                24 { "DDR3" }
                26 { "DDR4" }
                34 { "DDR5" }
                default { $module.SMBIOSMemoryType }  # Display raw code if unknown
            }

            # Convert form factor codes to human-readable format
            $formFactor = switch ($module.FormFactor) {
                8 { "DIMM (Desktop)" }   # Desktop memory module
                12 { "SODIMM (Laptop)" } # Laptop memory module
                default { $module.FormFactor }  # Display raw code if unknown
            }

            # Display detailed information for this memory module
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
    # Handle any errors that occur during CIM queries
    Write-Host " Error retrieving system information: $($_.Exception.Message)"
}