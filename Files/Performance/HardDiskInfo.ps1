function Write-Info {
    param([string]$Text)
    Write-Host $Text
}

function Format-Size {
    param([double]$SizeInBytes)
    $sizes = @("Bytes", "KB", "MB", "GB", "TB")
    $order = 0
    while ($SizeInBytes -ge 1024 -and $order -lt $sizes.Length - 1) {
        $order++
        $SizeInBytes = $SizeInBytes / 1024
    }
    
    return "{0:N2} {1}" -f $SizeInBytes, $sizes[$order]
}

Write-Info "Physical Disks:"
try {
    $disks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Sort-Object Index
    if ($disks) {
        $diskNumber = 1
        foreach ($disk in $disks) {
            $diskType = "Unknown"
            if ($disk.Model -match 'SSD|Solid State') {
                $diskType = "SSD (Solid State Drive)"
            }
            elseif ($disk.MediaType -match 'Fixed hard disk media') {
                $diskType = "HDD (Hard Disk Drive)"
            }
            elseif ($disk.SpindleSpeed -gt 0) {
                $diskType = "HDD (Hard Disk Drive)"
            }
            elseif ($disk.SpindleSpeed -eq 0 -and $disk.Size -gt 0) {
                $diskType = "SSD (Solid State Drive)"
            }
            
            Write-Info " Disk #$($disk.Index):"
            Write-Info "  Model:  $($disk.Model.Trim())"
            Write-Info "  Device ID:  $($disk.DeviceID)"
            Write-Info "  Serial Number:  $($disk.SerialNumber)"
            Write-Info "  Type:  $diskType"
            Write-Info "  Size:  $(Format-Size $disk.Size)"
            Write-Info "  Interface:  $($disk.InterfaceType)"
            Write-Info "  Total Sectors:  $($disk.TotalSectors)"
            Write-Host ""
            $diskNumber++
        }
    } else {
        Write-Info "  No disk information available"
    }
} catch {
    Write-Info "  Error retrieving disk information: $_"
}

Write-Info "Partitions:"
try {
    $partitions = Get-CimInstance Win32_DiskPartition -ErrorAction Stop | Sort-Object DiskIndex, Index
    if ($partitions) {
        foreach ($partition in $partitions) {
            $partitionType = switch ($partition.Type) {
                "GPT: System" { "GPT System" }
                "GPT: Basic Data" { "GPT Basic Data" }
                "GPT: Microsoft reserved" { "GPT Microsoft Reserved" }
                "Installable File System" { "Installable File System" }
                default { $partition.Type }
            }
            Write-Info "  Device ID:  $($partition.DeviceID)"
            Write-Info "  Type:  $partitionType"
            Write-Info "  Size:  $(Format-Size $partition.Size)"
            Write-Info "  Starting Offset:  $($partition.StartingOffset)"
            Write-Host ""
        }
    } else {
        Write-Info " No partition information available"
    }
} catch {
    Write-Info " Error retrieving partition information: $_"
}

Write-Info "Logical Drives:"
try {
    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Sort-Object DeviceID
    if ($drives) {
        $totalSystemStorage = 0
        $totalFreeStorage = 0
        
        foreach ($drive in $drives) {
            $driveType = switch ($drive.DriveType) {
                0 { 'Unknown' }
                1 { 'No Root Directory' }
                2 { 'Removable Disk' }
                3 { 'Local Disk' }
                4 { 'Network Drive' }
                5 { 'CD-ROM' }
                6 { 'RAM Disk' }
                default { 'Other' }
            }
            
            $driveName = if ($drive.VolumeName) { " ($($drive.VolumeName))" } else { "" }
            
            if ($drive.Size -gt 0) {
                $total = [math]::Round($drive.Size / 1GB, 2)
                $free = [math]::Round($drive.FreeSpace / 1GB, 2)
                $used = [math]::Round($total - $free, 2)
                $percent = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 2) } else { 0 }
                
                # Add to total system storage
                $totalSystemStorage += $total
                $totalFreeStorage += $free
                $driveInfo = " Drive {0}{1}:" -f $drive.DeviceID, $driveName
                Write-Info $driveInfo
                
                Write-Info "  Type: $driveType"
                Write-Info "  File System:  $($drive.FileSystem)"
                Write-Info "  Capacity:  $total GB"
                Write-Info "  Used Space:  $used GB"
                Write-Info "  Free Space:  $free GB"
                Write-Info "  Usage Percentage:  $percent%"
                
                Write-Host ""
            } else {
                $driveInfo = "  Drive {0}{1}:" -f $drive.DeviceID, $driveName
                Write-Info $driveInfo
                Write-Info "  Type:  $driveType"
                Write-Info "  File System:  $($drive.FileSystem)"
                Write-Info "  Capacity:  Not Available"
                Write-Host ""
            }
        }

        if ($totalSystemStorage -gt 0) {
            Write-Info "Total System Storage Statistics:"
            $totalUsedStorage = $totalSystemStorage - $totalFreeStorage
            $systemUsagePercent = [math]::Round(($totalUsedStorage / $totalSystemStorage) * 100, 2)
            
            Write-Info " Total Capacity:  $(Format-Size ($totalSystemStorage * 1GB))"
            Write-Info " Used Space:  $(Format-Size ($totalUsedStorage * 1GB))"
            Write-Info " Free Space:  $(Format-Size ($totalFreeStorage * 1GB))"
            Write-Info " System Usage:  $systemUsagePercent%"
        }
    } else {
        Write-Info " No logical drive information available"
    }
} catch {
    Write-Info " Error retrieving logical drive information: $_"
}