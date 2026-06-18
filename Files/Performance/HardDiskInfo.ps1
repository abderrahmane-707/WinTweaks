# Accept log file path from caller (no default fallback)
param (
    [string]$LogPath
)

# Write output to screen and log file using UTF-8 encoding
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogPath -Value $Message -Encoding utf8
}

# Convert raw bytes to human‑readable units (Bytes/KB/MB/GB/TB)
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

# Build accurate MediaType lookup (Index -> MediaType) via Get-PhysicalDisk
$physicalDiskTypeMap = @{}
try {
    Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
        $physicalDiskTypeMap["$($_.DeviceId)"] = $_.MediaType
    }
} catch {
    # Get-PhysicalDisk unavailable – will fall back to model‑name heuristics
}

# Physical disks
Write-Log "Physical Disks:"
try {
    $disks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Sort-Object Index
    if ($disks) {
        foreach ($disk in $disks) {
            $diskType = "Unknown"

            # Prefer accurate detection from Get-PhysicalDisk
            $mapKey = "$($disk.Index)"
            if ($physicalDiskTypeMap.ContainsKey($mapKey) -and $physicalDiskTypeMap[$mapKey] -notin @("Unspecified", $null, "")) {
                switch ($physicalDiskTypeMap[$mapKey]) {
                    "SSD" { $diskType = "SSD (Solid State Drive)" }
                    "HDD" { $diskType = "HDD (Hard Disk Drive)" }
                    "SCM" { $diskType = "SCM (Storage Class Memory)" }
                    default { $diskType = $physicalDiskTypeMap[$mapKey] }
                }
            }
            # Fallback: model‑name guess
            elseif ($disk.Model -match 'SSD|Solid State|NVMe') {
                $diskType = "SSD (Solid State Drive)"
            }

            $modelName = if ($disk.Model) { $disk.Model.Trim() } else { "Unknown" }

            Write-Log " Disk #$($disk.Index):"
            Write-Log "  Model:   $modelName"
            Write-Log "  Device ID:   $($disk.DeviceID)"
            Write-Log "  Serial Number:   $($disk.SerialNumber)"
            Write-Log "  Type:  $diskType"
            Write-Log "  Size:  $(Format-Size $disk.Size)"
            Write-Log "  Interface:   $($disk.InterfaceType)"
            Write-Log "  Total Sectors:   $($disk.TotalSectors)"
            Write-Log ""
        }
    } else {
        Write-Log "  No disk information available"
    }
} catch {
    Write-Log "  Error retrieving disk information: $_"
}

# Partitions
Write-Log "Partitions:"
try {
    $partitions = Get-CimInstance Win32_DiskPartition -ErrorAction Stop | Sort-Object DiskIndex, Index
    if ($partitions) {
        foreach ($partition in $partitions) {
            # Map common partition type codes
            $partitionType = switch ($partition.Type) {
                "GPT: System"                { "GPT System" }
                "GPT: Basic Data"            { "GPT Basic Data" }
                "GPT: Microsoft reserved"    { "GPT Microsoft Reserved" }
                "Installable File System"    { "Installable File System" }
                default                      { $partition.Type }
            }
            Write-Log "  Device ID:   $($partition.DeviceID)"
            Write-Log "  Type:  $partitionType"
            Write-Log "  Size:  $(Format-Size $partition.Size)"
            Write-Log "  Starting Offset:   $($partition.StartingOffset)"
            Write-Log ""
        }
    } else {
        Write-Log " No partition information available"
    }
} catch {
    Write-Log " Error retrieving partition information: $_"
}

# Logical drives
Write-Log "Logical Drives:"
try {
    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Sort-Object DeviceID
    if ($drives) {
        # Accumulate totals in bytes to avoid rounding errors
        $totalSystemStorageBytes = 0.0
        $totalFreeStorageBytes = 0.0

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

                $totalSystemStorageBytes += $drive.Size
                $totalFreeStorageBytes += $drive.FreeSpace

                Write-Log " Drive $($drive.DeviceID)$driveName`:"
                Write-Log "  Type: $driveType"
                Write-Log "  File System:   $($drive.FileSystem)"
                Write-Log "  Capacity:  $total GB"
                Write-Log "  Used Space:  $used GB"
                Write-Log "  Free Space:  $free GB"
                Write-Log "  Usage Percentage:  $percent%"
                Write-Log ""
            } else {
                Write-Log " Drive $($drive.DeviceID)$driveName`:"
                Write-Log "  Type:  $driveType"
                Write-Log "  File System:   $($drive.FileSystem)"
                Write-Log "  Capacity:  Not Available"
                Write-Log ""
            }
        }

        # System‑wide storage summary
        if ($totalSystemStorageBytes -gt 0) {
            Write-Log "Total System Storage Statistics:"
            $totalUsedStorageBytes = $totalSystemStorageBytes - $totalFreeStorageBytes
            $systemUsagePercent = [math]::Round(($totalUsedStorageBytes / $totalSystemStorageBytes) * 100, 2)

            Write-Log " Total Capacity:  $(Format-Size $totalSystemStorageBytes)"
            Write-Log " Used Space:  $(Format-Size $totalUsedStorageBytes)"
            Write-Log " Free Space:  $(Format-Size $totalFreeStorageBytes)"
            Write-Log " System Usage:  $systemUsagePercent%"
        }
    } else {
        Write-Log " No logical drive information available"
    }
} catch {
    Write-Log " Error retrieving logical drive information: $_"
}