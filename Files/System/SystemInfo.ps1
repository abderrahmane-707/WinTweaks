Write-Host "System Information:"
try {
    # Execute systeminfo command and suppress error output
    $output = systeminfo 2>$null
    if (-not $output) {
        throw "systeminfo returned no output"
    }
    
    # Flags to control which sections to skip during output processing
    $skipNetwork   = $false
    $skipProcessor = $false

    # Process each line of systeminfo output
    foreach ($line in $output) {
        # Skip the entire Network Card(s) section
        # When we encounter "Network Card(s):", set flag to skip until next non-empty line
        if ($line -match '^Network Card\(s\):') {
            $skipNetwork = $true
            continue  # Skip this line and move to next iteration
        }
        
        # If we're in the network section, skip lines until we hit a non-empty line
        if ($skipNetwork) {
            if ($line -match '^\S') {  # Line starts with non-whitespace (new section)
                $skipNetwork = $false
            } else {
                continue  # Skip this line (it's part of network section)
            }
        }
        
        # Skip the Processor(s) section lines that show individual processors
        if ($line -match '^Processor\(s\):') {
            $skipProcessor = $true
            continue
        }

        # If we're in the processor section, skip lines that show individual processors
        if ($skipProcessor) {
            if ($line -match '^\s+\[\d+\]:') {  # Lines like "  [01]: Intel ..."
                continue
            } else {
                $skipProcessor = $false
            }
        }
        
        # Skip specific lines that match these patterns (less important information)
        if ($line -match '^(OS Build Type:|Registered Organization:|Windows Directory:|Boot Device:|Domain:|Logon Server:|OS Configuration:|Hyper-V Requirements:)') {
            continue
        }
        
        # Display the line (with indentation)
        Write-Host "  $line"
    }
}
catch {
    Write-Host "  Error retrieving system information"
}

# Display system performance metrics header
Write-Host "`nSystem Performance:"
try {
    # Calculate CPU usage percentage (average across all cores)
    $cpuLoad = (Get-CimInstance Win32_Processor -ErrorAction Stop | 
                Measure-Object -Property LoadPercentage -Average).Average
    
    # Get memory information and calculate memory usage percentage
    $mem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    # Formula: (Total - Free) / Total * 100, rounded to 1 decimal place
    $memUsed = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 
                              $mem.TotalVisibleMemorySize) * 100, 1)
    
    # Get system drive (usually C:) information and calculate disk usage percentage
    $disk = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | 
            Where-Object { $_.DeviceID -eq $env:SystemDrive }
    
    # Calculate disk usage percentage if disk information is available
    $diskUsed = if ($disk) { 
        [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1) 
    } else { 
        "N/A"  # Disk information not available
    }
    
    # Display performance metrics
    Write-Host " CPU Usage: $cpuLoad %"
    Write-Host " Memory Usage: $memUsed %"
    Write-Host " System Disk Usage: $diskUsed %"
    
} catch {
    Write-Host " Error retrieving performance information"
}