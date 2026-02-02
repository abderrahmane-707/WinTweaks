# Helper function for consistent informational output
function Write-Info {
    param([string]$Text)
    Write-Host $Text
}

# Function to format byte sizes into human-readable units (Bytes, KB, MB, GB, TB)
function Format-Size {
    param([double]$SizeInBytes)
    $sizes = @("Bytes", "KB", "MB", "GB", "TB")
    $order = 0
    # Convert to appropriate unit by dividing by 1024 until size < 1024 or we reach TB
    while ($SizeInBytes -ge 1024 -and $order -lt $sizes.Length - 1) {
        $order++
        $SizeInBytes = $SizeInBytes / 1024
    }
    
    return "{0:N2} {1}" -f $SizeInBytes, $sizes[$order]  # Format with 2 decimal places
}

# Display physical disk information (hard drives, SSDs)
Write-Info "Physical Disks:"
try {
    # Retrieve all physical disk information using WMI/CIM
    $disks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Sort-Object Index
    if ($disks) {
        $diskNumber = 1
        foreach ($disk in $disks) {
            # Determine disk type (SSD or HDD) using multiple detection methods
            $diskType = "Unknown"
            if ($disk.Model -match 'SSD|Solid State') {
                $diskType = "SSD (Solid State Drive)"
            }
            elseif ($disk.MediaType -match 'Fixed hard disk media') {
                $diskType = "HDD (Hard Disk Drive)"
            }
            # HDDs have spindle rotation (RPM), SSDs don't
            elseif ($disk.SpindleSpeed -gt 0) {
                $diskType = "HDD (Hard Disk Drive)"
            }
            # SSDs typically report 0 RPM and have a size
            elseif ($disk.SpindleSpeed -eq 0 -and $disk.Size -gt 0) {
                $diskType = "SSD (Solid State Drive)"
            }
            
            # Display disk information
            Write-Info " Disk #$($disk.Index):"
            Write-Info "  Model:  $($disk.Model.Trim())"
            Write-Info "  Device ID:  $($disk.DeviceID)"  # e.g., \\.\PHYSICALDRIVE0
            Write-Info "  Serial Number:  $($disk.SerialNumber)"
            Write-Info "  Type:  $diskType"
            Write-Info "  Size:  $(Format-Size $disk.Size)"
            Write-Info "  Interface:  $($disk.InterfaceType)"  # SATA, NVMe, SCSI, etc.
            Write-Info "  Total Sectors:  $($disk.TotalSectors)"  # Total number of sectors
            Write-Host ""  # Empty line between disks
            $diskNumber++
        }
    } else {
        Write-Info "  No disk information available"
    }
} catch {
    Write-Info "  Error retrieving disk information: $_"
}

# Display partition information (logical divisions of physical disks)
Write-Info "Partitions:"
try {
    $partitions = Get-CimInstance Win32_DiskPartition -ErrorAction Stop | Sort-Object DiskIndex, Index
    if ($partitions) {
        foreach ($partition in $partitions) {
            # Convert partition type codes to human-readable descriptions
            $partitionType = switch ($partition.Type) {
                "GPT: System" { "GPT System" }  # EFI system partition
                "GPT: Basic Data" { "GPT Basic Data" }  # Standard data partition
                "GPT: Microsoft reserved" { "GPT Microsoft Reserved" }  # MSR partition
                "Installable File System" { "Installable File System" }  # Standard partition
                default { $partition.Type }  # Use raw type if unknown
            }
            Write-Info "  Device ID:  $($partition.DeviceID)"  # e.g., Disk #0, Partition #1
            Write-Info "  Type:  $partitionType"
            Write-Info "  Size:  $(Format-Size $partition.Size)"
            Write-Info "  Starting Offset:  $($partition.StartingOffset)"  # Starting byte position on disk
            Write-Host ""  # Empty line between partitions
        }
    } else {
        Write-Info " No partition information available"
    }
} catch {
    Write-Info " Error retrieving partition information: $_"
}

# Display logical drives information (drive letters and volumes)
Write-Info "Logical Drives:"
try {
    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Sort-Object DeviceID
    if ($drives) {
        $totalSystemStorage = 0
        $totalFreeStorage = 0
        
        foreach ($drive in $drives) {
            # Convert drive type codes to human-readable descriptions
            $driveType = switch ($drive.DriveType) {
                0 { 'Unknown' }
                1 { 'No Root Directory' }
                2 { 'Removable Disk' }    # USB drives, memory cards
                3 { 'Local Disk' }        # Internal hard drives, SSDs
                4 { 'Network Drive' }     # Mapped network drives
                5 { 'CD-ROM' }            # Optical drives
                6 { 'RAM Disk' }          # RAM disks
                default { 'Other' }
            }
            
            $driveName = if ($drive.VolumeName) { " ($($drive.VolumeName))" } else { "" }
            
            if ($drive.Size -gt 0) {
                # Convert sizes from bytes to GB
                $total = [math]::Round($drive.Size / 1GB, 2)
                $free = [math]::Round($drive.FreeSpace / 1GB, 2)
                $used = [math]::Round($total - $free, 2)
                $percent = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 2) } else { 0 }
                
                # Accumulate totals for system-wide storage summary
                $totalSystemStorage += $total
                $totalFreeStorage += $free
                $driveInfo = " Drive {0}{1}:" -f $drive.DeviceID, $driveName
                Write-Info $driveInfo
                
                Write-Info "  Type: $driveType"
                Write-Info "  File System:  $($drive.FileSystem)"  # NTFS, FAT32, exFAT, etc.
                Write-Info "  Capacity:  $total GB"
                Write-Info "  Used Space:  $used GB"
                Write-Info "  Free Space:  $free GB"
                Write-Info "  Usage Percentage:  $percent%"
                
                Write-Host ""
            } else {
                # Handle drives with no size information (e.g., empty CD-ROM)
                $driveInfo = "  Drive {0}{1}:" -f $drive.DeviceID, $driveName
                Write-Info $driveInfo
                Write-Info "  Type:  $driveType"
                Write-Info "  File System:  $($drive.FileSystem)"
                Write-Info "  Capacity:  Not Available"
                Write-Host ""
            }
        }

        # Display system-wide storage summary if we have valid data
        if ($totalSystemStorage -gt 0) {
            Write-Info "Total System Storage Statistics:"
            $totalUsedStorage = $totalSystemStorage - $totalFreeStorage
            $systemUsagePercent = [math]::Round(($totalUsedStorage / $totalSystemStorage) * 100, 2)
            
            # Convert back to bytes for Format-Size function
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