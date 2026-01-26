Write-Host "System Information:"
try {
    $output = systeminfo 2>$null
    if (-not $output) {
        throw "systeminfo returned no output"
    }
    $skipNetwork   = $false
    $skipProcessor = $false

    foreach ($line in $output) {
        if ($line -match '^Network Card\(s\):') {
            $skipNetwork = $true
            continue
        }
        if ($skipNetwork) {
            if ($line -match '^\S') {
                $skipNetwork = $false
            } else {
                continue
            }
        }
        if ($line -match '^Processor\(s\):') {
            $skipProcessor = $true
            continue
        }

        if ($skipProcessor) {
            if ($line -match '^\s+\[\d+\]:') {
                continue
            } else {
                $skipProcessor = $false
            }
        }
        if ($line -match '^(OS Build Type:|Registered Organization:|Windows Directory:|Boot Device:|Domain:|Logon Server:|OS Configuration:|Hyper-V Requirements:)') {
            continue
        }
        Write-Host "  $line"
    }
}
catch {
    Write-Host "  Error retrieving system information"
}

Write-Host "`nSystem Performance:"
try {
    $cpuLoad = (Get-CimInstance Win32_Processor -ErrorAction Stop | Measure-Object -Property LoadPercentage -Average).Average
    $mem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $memUsed = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 1)
    $disk = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DeviceID -eq $env:SystemDrive }
    $diskUsed = if ($disk) { [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1) } else { "N/A" }
    
    Write-Host " CPU Usage: $cpuLoad %"
    Write-Host " Memory Usage: $memUsed %"
    Write-Host " System Disk Usage: $diskUsed %"
    
} catch {
    Write-Host " Error retrieving performance information"
}