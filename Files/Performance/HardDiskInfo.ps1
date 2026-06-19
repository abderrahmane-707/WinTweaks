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
    if ($SizeInBytes -le 0 -or $SizeInBytes -eq $null) { return "N/A" }
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
            $diskType = "N/A"

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

            $modelName = if ($disk.Model) { $disk.Model.Trim() } else { "N/A" }
            $serialNumber = if ($disk.SerialNumber) { $disk.SerialNumber.Trim() } else { "N/A" }
            $interfaceType = if ($disk.InterfaceType) { $disk.InterfaceType.Trim() } else { "N/A" }
            $totalSectors = if ($disk.TotalSectors) { $disk.TotalSectors } else { "N/A" }
            $diskSize = if ($disk.Size) { Format-Size $disk.Size } else { "N/A" }

            Write-Log " Disk #$($disk.Index):"
            Write-Log "   Model:             $modelName"
            Write-Log "   Device ID:         $($disk.DeviceID)"
            Write-Log "   Serial Number:     $serialNumber"
            Write-Log "   Type:              $diskType"
            Write-Log "   Size:              $diskSize"
            Write-Log "   Interface:         $interfaceType"
            Write-Log "   Total Sectors:     $totalSectors"
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
            $partitionType = if ($partition.Type) {
                switch ($partition.Type) {
                    "GPT: System"                { "GPT System" }
                    "GPT: Basic Data"            { "GPT Basic Data" }
                    "GPT: Microsoft reserved"    { "GPT Microsoft Reserved" }
                    "Installable File System"    { "Installable File System" }
                    default                      { $partition.Type }
                }
            } else { "N/A" }

            $partitionSize = if ($partition.Size) { Format-Size $partition.Size } else { "N/A" }
            $startingOffset = if ($partition.StartingOffset) { $partition.StartingOffset } else { "N/A" }

            Write-Log "  Device ID:         $($partition.DeviceID)"
            Write-Log "  Type:              $partitionType"
            Write-Log "  Size:              $partitionSize"
            Write-Log "  Starting Offset:   $startingOffset"
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
        $totalSystemStorageBytes = 0.0
        $totalFreeStorageBytes = 0.0

        foreach ($drive in $drives) {
            $driveType = switch ($drive.DriveType) {
                0 { 'N/A' }
                1 { 'No Root Directory' }
                2 { 'Removable Disk' }
                3 { 'Local Disk' }
                4 { 'Network Drive' }
                5 { 'CD-ROM' }
                6 { 'RAM Disk' }
                default { 'N/A' }
            }

            # Extract drive letter only (e.g., "C:")
            $cleanID = $drive.DeviceID.TrimEnd(':')
            $driveHeader = "$($cleanID):"
            
            $fileSystem = if ($drive.FileSystem) { $drive.FileSystem } else { "N/A" }

            if ($drive.Size -gt 0) {
                $total = [math]::Round($drive.Size / 1GB, 2)
                $free = [math]::Round($drive.FreeSpace / 1GB, 2)
                $used = [math]::Round($total - $free, 2)
                $percent = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 2) } else { 0 }

                $totalSystemStorageBytes += $drive.Size
                $totalFreeStorageBytes += $drive.FreeSpace

                Write-Log " Drive $driveHeader"
                Write-Log "   Type:              $driveType"
                Write-Log "   File System:       $fileSystem"
                Write-Log "   Capacity:          $total GB"
                Write-Log "   Used Space:        $used GB"
                Write-Log "   Free Space:        $free GB"
                Write-Log "   Usage Percentage:  $percent%"
                Write-Log ""
            } else {
                Write-Log " Drive $driveHeader"
                Write-Log "   Type:              $driveType"
                Write-Log "   File System:       $fileSystem"
                Write-Log "   Capacity:          N/A"
                Write-Log ""
            }
        }

        # System‑wide storage summary
        if ($totalSystemStorageBytes -gt 0) {
            Write-Log "Total System Storage Statistics:"
            $totalUsedStorageBytes = $totalSystemStorageBytes - $totalFreeStorageBytes
            $systemUsagePercent = [math]::Round(($totalUsedStorageBytes / $totalSystemStorageBytes) * 100, 2)

            Write-Log " Total Capacity:     $(Format-Size $totalSystemStorageBytes)"
            Write-Log " Used Space:         $(Format-Size $totalUsedStorageBytes)"
            Write-Log " Free Space:         $(Format-Size $totalFreeStorageBytes)"
            Write-Log " System Usage:       $systemUsagePercent%"
        }
    } else {
        Write-Log " No logical drive information available"
    }
} catch {
    Write-Log " Error retrieving logical drive information: $_"
}