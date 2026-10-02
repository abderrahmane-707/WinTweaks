param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

$ci = [System.Globalization.CultureInfo]::InvariantCulture
$systemDrive = $env:SystemDrive

# Binary units (1024) - independent of the machine's culture
function Format-Size {
    param([double]$SizeInBytes)
    if ($SizeInBytes -le 0) { return 'N/A' }
    $sizes = 'Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'
    $order = 0
    while ($SizeInBytes -ge 1024 -and $order -lt $sizes.Length - 1) {
        $order++
        $SizeInBytes /= 1024
    }
    return '{0} {1}' -f $SizeInBytes.ToString('F2', $script:ci), $sizes[$order]
}

# Decimal units (1000) - matches the size printed on the disk label
function Format-DecimalSize {
    param([double]$SizeInBytes)
    if ($SizeInBytes -le 0) { return 'N/A' }
    $units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'
    $o = 0
    while ($SizeInBytes -ge 1000 -and $o -lt $units.Length - 1) {
        $o++
        $SizeInBytes /= 1000
    }
    return '{0} {1}' -f $SizeInBytes.ToString('F2', $script:ci), $units[$o]
}

# Return "N/A" for empty values
function Get-Value {
    param ($Value, [string]$Suffix = '')
    $text = "$Value".Trim()
    if ($null -eq $Value -or $text -eq '') { return 'N/A' }
    return "$text$Suffix"
}

function Get-YesNo {
    param ($Value)
    if ($null -eq $Value) { return 'N/A' }
    if ($Value) { return 'Yes' }
    return 'No'
}

# Formatted line (label: value) with uniform indentation
function Write-Field {
    param ([string]$Label, $Value, [int]$Indent = 4)
    Write-Log ((' ' * $Indent) + ("${Label}:").PadRight(26) + " $Value")
}

# Disk type: MediaType then BusType then SpindleSpeed then model name
function Get-DiskTypeText {
    param ($PhysicalDisk, [string]$Model)

    if ($Model -match 'Virtual|VMware|Msft|QEMU|VBOX') { return 'Virtual Disk' }

    if ($PhysicalDisk) {
        $bus    = "$($PhysicalDisk.BusType)"
        $suffix = if ($bus) { " ($bus)" } else { '' }

        # USB flash: may be reported as SSD or Unspecified, but it is not a real SSD
        if ($bus -eq 'USB' -and $Model -match 'Flash|Cruzer|DataTraveler|Thumb') { return 'USB Flash Drive (non-rotating)' }

        switch ("$($PhysicalDisk.MediaType)") {
            'SSD' { return "SSD$suffix" }
            'HDD' { return "HDD$suffix" }
            'SCM' { return "SCM (Storage Class Memory)$suffix" }
        }

        # MediaType unspecified: SpindleSpeed = 0 means a non-rotating disk
        $spin = $PhysicalDisk.SpindleSpeed
        if ($null -ne $spin) {
            if ($spin -eq 0 -and $bus -eq 'USB') { return 'USB Flash Drive (non-rotating)' }
            if ($spin -eq 0) { return "SSD$suffix - detected by spindle speed" }
            if ($spin -gt 0 -and $spin -ne [uint32]::MaxValue) { return "HDD$suffix - $spin RPM" }
        }
    }

    if ($Model -match 'SSD|Solid State|NVMe') { return 'SSD - guessed from model name' }
    return 'Unknown'
}

function Get-DriveTypeText {
    param ([int]$Type)
    switch ($Type) {
        1 { 'No Root Directory' }
        2 { 'Removable Disk' }
        3 { 'Local Disk' }
        4 { 'Network Drive' }
        5 { 'CD-ROM' }
        6 { 'RAM Disk' }
        default { 'N/A' }
    }
}

# Actual sector format: 512n / 512e / 4Kn
function Get-SectorFormat {
    param ($Logical, $Physical)
    if (-not $Logical -or -not $Physical) { return $null }
    if ($Logical -eq 512 -and $Physical -eq 512)  { return '512n' }
    if ($Logical -eq 512 -and $Physical -eq 4096) { return '512e (Advanced Format)' }
    if ($Logical -eq 4096 -and $Physical -eq 4096) { return '4Kn' }
    return $null
}

# Partition alignment: 1MB is best, 4KB is the minimum for good performance
function Get-AlignmentText {
    param ($Offset)
    if ($null -eq $Offset) { return 'N/A' }
    $o = [uint64]$Offset
    if ($o % 1MB -eq 0)  { return 'Yes (1 MB)' }
    if ($o % 4096 -eq 0) { return 'Yes (4 KB)' }
    return 'No - misaligned, may reduce performance'
}

# Partition type name: Get-Partition (Type/GptType) then Win32_DiskPartition as fallback
function Get-PartitionTypeText {
    param ($Part, $GetPart)

    if ($GetPart) {
        $type = "$($GetPart.Type)"
        $guid = "$($GetPart.GptType)".Trim('{', '}').ToLower()

        $guidNames = @{
            'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' = 'EFI System Partition'
            'e3c9e316-0b5c-4db8-817d-f92df00215ae' = 'Microsoft Reserved (MSR)'
            'ebd0a0a2-b9e5-4433-87c0-68b6b72699c7' = 'Basic Data'
            'de94bba4-06d1-4d40-a16a-bfd50179d6ac' = 'Windows Recovery'
            '0fc63daf-8483-4772-8e79-3d69d8477de4' = 'Linux Filesystem'
            '0657fd6d-a4ab-43c4-84e5-0933c84b4f4f' = 'Linux Swap'
            'd3bfe2de-3daf-11df-ba40-e3a556d89593' = 'Intel Rapid Start'
        }

        if ($guid -and $guidNames.ContainsKey($guid)) { return "GPT: $($guidNames[$guid])" }
        if ($guid) {
            if ($type -and $type -ne 'Unknown') { return "GPT: $type" }
            return "GPT: Unknown ($guid)"
        }
        if ($type -and $type -ne 'Unknown') { return $type }
    }
    return (Get-Value $Part.Type)
}

# Storage controller mode inferred from the driver/controller name
function Get-ControllerModeText {
    param ([string]$Name)
    if ($Name -match 'Storage Spaces')                                    { return 'Virtual (Storage Spaces)' }
    if ($Name -match 'NVM Express|NVMe')                                  { return 'NVMe' }
    if ($Name -match 'RAID|Rapid Storage|\bRST\b|MegaRAID|Smart Array')   { return 'RAID' }
    if ($Name -match 'AHCI')                                              { return 'AHCI' }
    if ($Name -match 'Virtual|VMware|Hyper-V|VirtIO|Msft')                { return 'Virtual' }
    if ($Name -match '\bUSB\b|UASP|Mass Storage')                         { return 'USB' }
    if ($Name -match '\bIDE\b|\bPATA\b|\bATA\b')                          { return 'IDE / Legacy ATA' }
    return 'Unknown'
}

# NTFS details (fsutil labels are English-only)
function Get-NtfsInfo {
    param ([string]$Letter)
    try {
        $out = & fsutil fsinfo ntfsinfo $Letter 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
        $info = @{}
        foreach ($l in $out) {
            if ($l -match '^\s*NTFS Version\s*:\s*(.+)$')           { $info.Version = $Matches[1].Trim() }
            if ($l -match '^\s*Mft Valid Data Length\s*:\s*(.+)$')  { $info.Mft     = $Matches[1].Trim() }
        }
        if ($info.Count -eq 0) { return $null }
        return $info
    } catch { return $null }
}

#  Collect data from the Storage module (with clear log on failure)
$physicalDisks = @()
try {
    $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)
} catch {
    Write-Log "Note: Get-PhysicalDisk unavailable ($($_.Exception.Message)); disk type falls back to model-name heuristics."
}

$diskDetails = @{}
try {
    Get-Disk -ErrorAction Stop | ForEach-Object { $diskDetails["$($_.Number)"] = $_ }
} catch { }

$partitionMap = @{}
try {
    Get-Partition -ErrorAction Stop | ForEach-Object { $partitionMap["$($_.DiskNumber):$($_.Offset)"] = $_ }
} catch { }

$volumeMap = @{}
try {
    Get-Volume -ErrorAction Stop |
        Where-Object { "$($_.DriveLetter)".Trim([char]0) -ne '' } |
        ForEach-Object { $volumeMap["$($_.DriveLetter):"] = $_ }
} catch { }

# Win32_Volume: dirty bit, compression, indexing, volume id -> drive letter
$win32Volumes  = @{}
$volIdToLetter = @{}
try {
    Get-CimInstance Win32_Volume -ErrorAction Stop | ForEach-Object {
        if ($_.DriveLetter) {
            $win32Volumes[$_.DriveLetter]  = $_
            $volIdToLetter[$_.DeviceID]    = $_.DriveLetter
        }
    }
} catch { }

# Shadow copies / System Restore
$shadowStorage = @{}
$shadowCount   = @{}
try {
    foreach ($s in @(Get-CimInstance Win32_ShadowStorage -ErrorAction Stop)) {
        $l = $volIdToLetter[$s.Volume.DeviceID]
        if ($l) { $shadowStorage[$l] = $s }
    }
    foreach ($c in @(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop)) {
        $l = $volIdToLetter[$c.VolumeName]
        if ($l) { $shadowCount[$l] = 1 + [int]$shadowCount[$l] }
    }
} catch { }

# Pagefiles
$pageFiles = @{}
try {
    Get-CimInstance Win32_PageFileUsage -ErrorAction Stop | ForEach-Object {
        $pageFiles[$_.Name.Substring(0, 2).ToUpper()] = $_
    }
} catch { }

# BitLocker
$bitLockerMap     = @{}
$bitLockerQueried = $false
try {
    $bl = @(Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftVolumeEncryption' -ClassName Win32_EncryptableVolume -ErrorAction Stop)
    $bitLockerQueried = $true
    foreach ($v in $bl) {
        $state = switch ([int]$v.ProtectionStatus) {
            0 { 'Off' }
            1 { 'On' }
            default { 'Unknown' }
        }
        $bitLockerMap["$($v.DriveLetter)"] = $state
    }
} catch { }

# BitLocker details (method, percentage, lock status, protectors)
$bitLockerDetail = @{}
try {
    Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
        $bitLockerDetail["$($_.MountPoint)".TrimEnd('\')] = $_
    }
} catch { }

# SMART failure prediction
$failurePredict = @()
try {
    $failurePredict = @(Get-CimInstance -Namespace 'root\wmi' -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop)
} catch { }

# TRIM state (global setting)
$trimText = 'N/A'
try {
    $trimOut = & fsutil behavior query DisableDeleteNotify 2>$null
    $trimParts = @()
    foreach ($l in $trimOut) {
        if ($l -match '(NTFS|ReFS)?\s*DisableDeleteNotify\s*=\s*(\d)') {
            $fsName = if ($Matches[1]) { $Matches[1] } else { 'NTFS' }
            $state  = if ($Matches[2] -eq '0') { 'Enabled' } else { 'Disabled' }
            $trimParts += "$fsName $state"
        }
    }
    if ($trimParts.Count -gt 0) { $trimText = $trimParts -join ', ' }
} catch { }

# Match Win32_DiskDrive with Get-PhysicalDisk: by number then by serial number
function Find-PhysicalDisk {
    param ($Disk)
    $pd = $physicalDisks | Where-Object { "$($_.DeviceId)" -eq "$($Disk.Index)" } | Select-Object -First 1
    if (-not $pd -and $Disk.SerialNumber) {
        $sn = $Disk.SerialNumber.Trim()
        $pd = $physicalDisks | Where-Object { $_.SerialNumber -and $_.SerialNumber.Trim() -eq $sn } | Select-Object -First 1
    }
    return $pd
}

#  Physical disks and their partitions
Write-Log "Physical Disks:"
try {
    $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Sort-Object Index)
    if ($disks.Count -gt 0) {
        foreach ($disk in $disks) {
            $pd  = Find-PhysicalDisk $disk
            $det = $diskDetails["$($disk.Index)"]

            $modelName = if ($disk.Model) { $disk.Model.Trim() } else { 'N/A' }
            $diskType  = Get-DiskTypeText $pd $modelName
            $bus       = if ($pd -and $pd.BusType) { "$($pd.BusType)" } else { $disk.InterfaceType }

            $firmware = if ($det -and $det.FirmwareVersion) { $det.FirmwareVersion } else { $disk.FirmwareRevision }

            $logical  = if ($det -and $det.LogicalSectorSize)  { $det.LogicalSectorSize }  else { $disk.BytesPerSector }
            $physical = if ($det -and $det.PhysicalSectorSize) { $det.PhysicalSectorSize } else { $null }
            $sectorText = "$logical B logical"
            if ($physical) { $sectorText += " / $physical B physical" }
            $fmt = Get-SectorFormat $logical $physical
            if ($fmt) { $sectorText += " ($fmt)" }

            $isExternal = ("$bus" -eq 'USB') -or ("$($disk.InterfaceType)" -eq 'USB') -or ("$($disk.MediaType)" -match 'External|Removable')

            $sizeText = if ($disk.Size) { "$(Format-Size $disk.Size) ($(Format-DecimalSize $disk.Size) decimal)" } else { 'N/A' }

            Write-Log "  Disk #$($disk.Index):"
            Write-Field 'Model'             $modelName
            Write-Field 'Device ID'         $disk.DeviceID
            Write-Field 'Serial Number'     (Get-Value $(if ($disk.SerialNumber) { $disk.SerialNumber.Trim() }))
            Write-Field 'Type'              $diskType
            Write-Field 'Bus Type'          (Get-Value $bus)
            Write-Field 'External / USB'    $(if ($isExternal) { 'Yes' } else { 'No' })
            Write-Field 'Size'              $sizeText
            Write-Field 'Firmware'          (Get-Value $firmware)
            Write-Field 'Partition Style'   (Get-Value $(if ($det) { $det.PartitionStyle }))
            Write-Field 'Sector Size'       $sectorText

            # Disk state (Get-Disk)
            if ($det) {
                Write-Field 'Boot Disk'           (Get-YesNo $det.IsBoot)
                Write-Field 'System Disk'         (Get-YesNo $det.IsSystem)
                Write-Field 'Offline'             (Get-YesNo $det.IsOffline)
                if ($det.IsOffline) { Write-Field 'Offline Reason' (Get-Value $det.OfflineReason) }
                Write-Field 'Read-Only'           (Get-YesNo $det.IsReadOnly)
                Write-Field 'Disk GUID'           (Get-Value $det.Guid)
                Write-Field 'MBR Signature'       (Get-Value $det.Signature)
                Write-Field 'Largest Free Extent' $(if ($null -ne $det.LargestFreeExtent) { if ($det.LargestFreeExtent -lt 8MB) { 'None' } else { Format-Size $det.LargestFreeExtent } } else { 'N/A' })
            }

            # Storage Spaces eligibility and spindle speed
            if ($pd) {
                Write-Field 'Can Pool' (Get-YesNo $pd.CanPool)
                if (-not $pd.CanPool -and $pd.CannotPoolReason) {
                    Write-Field 'Cannot Pool Reason' ((@($pd.CannotPoolReason) | ForEach-Object { "$_" }) -join ', ')
                }
                $spindleNum = [uint32]0
                if ([uint32]::TryParse("$($pd.SpindleSpeed)", [ref]$spindleNum) -and $spindleNum -gt 0 -and $spindleNum -ne [uint32]::MaxValue) {
                    Write-Field 'Spindle Speed' "$spindleNum RPM"
                }
            }

            # TRIM applies to SSDs
            if ($diskType -like 'SSD*') { Write-Field 'TRIM (Windows)' $trimText }

            # Health
            $health = if ($pd) { Get-Value $pd.HealthStatus } else { 'N/A' }
            $opStat = if ($pd -and $pd.OperationalStatus) { ($pd.OperationalStatus | ForEach-Object { "$_" }) -join ', ' } else { 'N/A' }
            Write-Field 'Health Status'     $health
            Write-Field 'Operational Status' $opStat

            # Partitions associated with this disk
            $parts = @(Get-CimAssociatedInstance -InputObject $disk -ResultClassName Win32_DiskPartition -ErrorAction SilentlyContinue |
                       Sort-Object StartingOffset)
            $usedByParts = ($parts | Measure-Object -Property Size -Sum).Sum
            if ($null -eq $usedByParts) { $usedByParts = 0 }
            $unallocated = [double]$disk.Size - [double]$usedByParts
            if (-not $det -or $null -eq $det.LargestFreeExtent) {
                Write-Field 'Unallocated Space' $(if ($unallocated -lt 8MB) { 'None' } else { Format-Size $unallocated })
            }

            if ($parts.Count -gt 0) {
                Write-Log "    Partitions ($($parts.Count)):"
                foreach ($part in $parts) {
                    $ld      = @(Get-CimAssociatedInstance -InputObject $part -ResultClassName Win32_LogicalDisk -ErrorAction SilentlyContinue)
                    $letters = ($ld | ForEach-Object { $_.DeviceID }) -join ', '

                    $flags = @()
                    if ($part.BootPartition)    { $flags += 'Boot' }
                    if ($part.PrimaryPartition) { $flags += 'Primary' }
                    if ($systemDrive -and ($ld | Where-Object { $_.DeviceID -eq $systemDrive })) { $flags += 'Windows' }

                    $offsetText = if ($null -ne $part.StartingOffset) {
                        if ($part.StartingOffset -eq 0) { '0 Bytes' } else { Format-Size $part.StartingOffset }
                    } else { 'N/A' }

                    $gp = $partitionMap["$($disk.Index):$($part.StartingOffset)"]
                    if ($gp -and $gp.IsHidden) { $flags += 'Hidden' }

                    Write-Log "      Partition #$($part.Index):"
                    Write-Field 'Type'            (Get-PartitionTypeText $part $gp) 8
                    Write-Field 'Size'            (Format-Size $part.Size) 8
                    Write-Field 'Starting Offset' $offsetText 8
                    Write-Field 'Aligned'         (Get-AlignmentText $part.StartingOffset) 8
                    Write-Field 'Drive Letter'    $(if ($letters) { $letters } else { '-' }) 8
                    Write-Field 'Flags'           $(if ($flags.Count -gt 0) { $flags -join ', ' } else { '-' }) 8
                }
            } else {
                Write-Log "    No partitions found on this disk."
            }

            Write-Log ""
        }
    } else {
        Write-Log "  No disk information available"
    }
} catch {
    Write-Log "  Error retrieving disk information: $($_.Exception.Message)"
}

#  Logical drives
Write-Log "Logical Drives:"
try {
    $localDrives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop | Sort-Object DeviceID)
    $otherDrives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType <> 3' -ErrorAction SilentlyContinue | Sort-Object DeviceID)

    if ($localDrives.Count -gt 0) {
        foreach ($drive in $localDrives) {
            $letter = $drive.DeviceID
            $vol    = $volumeMap[$letter]
            $wv     = $win32Volumes[$letter]
            $fs     = Get-Value $drive.FileSystem

            $bitLocker = if ($bitLockerMap.ContainsKey($letter)) { $bitLockerMap[$letter] }
                         elseif (-not $bitLockerQueried) { 'N/A' }
                         else { 'N/A' }

            $clusterSize = $null
            if ($vol -and $vol.AllocationUnitSize) { $clusterSize = [double]$vol.AllocationUnitSize }
            elseif ($wv -and $wv.BlockSize)        { $clusterSize = [double]$wv.BlockSize }

            $header = "  Drive $letter"
            if ($letter -eq $systemDrive) { $header += ' (System Drive)' }
            Write-Log $header
            Write-Field 'Type'         (Get-DriveTypeText $drive.DriveType)
            Write-Field 'Label'        $(if ($drive.VolumeName) { $drive.VolumeName } else { '(none)' })
            Write-Field 'Volume Serial' (Get-Value $drive.VolumeSerialNumber)
            Write-Field 'File System'  $fs
            Write-Field 'Cluster Size'  $(if ($clusterSize) { Format-Size $clusterSize } else { 'N/A' })

            # Volume health, dirty bit, compression, indexing
            Write-Field 'Volume Health'   $(if ($vol) { Get-Value $vol.HealthStatus } else { 'N/A' })
            Write-Field 'Volume Op. Status' $(if ($vol) { (@($vol.OperationalStatus) | ForEach-Object { "$_" }) -join ', ' } else { 'N/A' })
            Write-Field 'Dirty Bit'       $(if ($wv) { if ($wv.DirtyBitSet) { 'Yes - chkdsk recommended' } else { 'No' } } else { 'N/A' })
            Write-Field 'Compressed'      (Get-YesNo $drive.Compressed)
            Write-Field 'Indexing Enabled' $(if ($wv) { Get-YesNo $wv.IndexingEnabled } else { 'N/A' })

            # NTFS details
            if ($fs -eq 'NTFS') {
                $ntfs = Get-NtfsInfo $letter
                if ($ntfs) {
                    Write-Field 'NTFS Version' (Get-Value $ntfs.Version)
                    Write-Field 'MFT Size'      (Get-Value $ntfs.Mft)
                } else {
                    Write-Field 'NTFS Details' 'N/A'
                }
            }

            # BitLocker
            Write-Field 'BitLocker'     $bitLocker
            $bld = $bitLockerDetail[$letter]
            if ($bld -and "$($bld.VolumeStatus)" -ne 'FullyDecrypted') {
                $protectors = (@($bld.KeyProtector) | ForEach-Object { "$($_.KeyProtectorType)" }) -join ', '
                Write-Field 'BitLocker Method'     (Get-Value $bld.EncryptionMethod)
                Write-Field 'BitLocker Encrypted'  "$(Get-Value $bld.EncryptionPercentage)%"
                Write-Field 'BitLocker Lock Status' (Get-Value $bld.LockStatus)
                Write-Field 'BitLocker Protectors' $(if ($protectors) { $protectors } else { 'N/A' })
            }

            # Shadow copies / System Restore
            $ss = $shadowStorage[$letter]
            if ($ss) {
                $maxText = if ([double]$ss.MaxSpace -ge 1e18) { 'Unlimited' } else { Format-Size $ss.MaxSpace }
                Write-Field 'Shadow Copies' "$([int]$shadowCount[$letter]) copies, used $(Format-Size $ss.UsedSpace), max $maxText"
            } else {
                Write-Field 'Shadow Copies' 'None'
            }

            # Pagefile
            $pf = $pageFiles[$letter.ToUpper()]
            if ($pf) {
                Write-Field 'Pagefile' "$($pf.Name) - allocated $(Format-Size ([double]$pf.AllocatedBaseSize * 1MB)), in use $($pf.CurrentUsage) MB, peak $($pf.PeakUsage) MB"
            }

            if ($drive.Size -gt 0) {
                $usedBytes = [double]$drive.Size - [double]$drive.FreeSpace
                $usedPct   = [math]::Round($usedBytes / $drive.Size * 100, 1)

                Write-Field 'Capacity'    (Format-Size $drive.Size)
                Write-Field 'Used Space'  (Format-Size $usedBytes)
                Write-Field 'Free Space'  (Format-Size $drive.FreeSpace)
                Write-Field 'Usage'       "$($usedPct.ToString('F1', $ci))%"

            } else {
                Write-Field 'Capacity' 'N/A'
            }

            Write-Log ""
        }
    } else {
        Write-Log "  No local drive information available"
        Write-Log ""
    }

    # Removable / network / optical drives (not included in totals)
    if ($otherDrives.Count -gt 0) {
        Write-Log "Other Drives (not included in totals):"
        foreach ($drive in $otherDrives) {
            $cap = if ($drive.Size -gt 0) { Format-Size $drive.Size } else { 'N/A' }
            Write-Log "  Drive $($drive.DeviceID)"
            Write-Field 'Type'        (Get-DriveTypeText $drive.DriveType)
            Write-Field 'File System' (Get-Value $drive.FileSystem)
            Write-Field 'Capacity'    $cap
            if ($drive.DriveType -eq 4 -and $drive.ProviderName) {
                Write-Field 'Path' $drive.ProviderName
            }
            Write-Log ""
        }
    }
} catch {
    Write-Log "  Error retrieving logical drive information: $($_.Exception.Message)"
}

#  Storage controllers (AHCI / RAID / NVMe)
Write-Log "Storage Controllers:"
$raidControllers = @()
try {
    $controllers = @()
    $controllers += @(Get-CimInstance Win32_IDEController  -ErrorAction SilentlyContinue)
    $controllers += @(Get-CimInstance Win32_SCSIController -ErrorAction SilentlyContinue)
    if ($controllers.Count -gt 0) {
        $i = 0
        foreach ($c in $controllers) {
            $mode = Get-ControllerModeText "$($c.Name) $($c.Caption)"
            if ($mode -eq 'RAID') { $raidControllers += $c.Name }
            Write-Log "  Controller #${i}:"
            Write-Field 'Name'         (Get-Value $c.Name)
            Write-Field 'Manufacturer' (Get-Value $c.Manufacturer)
            Write-Field 'Mode'         $mode
            Write-Field 'Status'       (Get-Value $c.Status)
            Write-Log ""
            $i++
        }
    } else {
        Write-Log "  No controller information available"
        Write-Log ""
    }
} catch {
    Write-Log "  Error retrieving controller information: $($_.Exception.Message)"
}

Write-Log "Storage Settings:"
Write-Field 'TRIM (DisableDeleteNotify)' $trimText 2
Write-Log ""

#  Storage Spaces and RAID
Write-Log "Storage Spaces / Pools:"
try {
    $pools = @(Get-StoragePool -ErrorAction Stop | Where-Object { -not $_.IsPrimordial })
    if ($pools.Count -gt 0) {
        foreach ($pool in $pools) {
            Write-Log "  Pool: $($pool.FriendlyName)"
            Write-Field 'Health Status'      (Get-Value $pool.HealthStatus)
            Write-Field 'Operational Status' ((@($pool.OperationalStatus) | ForEach-Object { "$_" }) -join ', ')
            Write-Field 'Read-Only'          (Get-YesNo $pool.IsReadOnly)
            Write-Field 'Size'               (Format-Size $pool.Size)
            Write-Field 'Allocated'          (Format-Size $pool.AllocatedSize)
            try {
                $members = @(Get-PhysicalDisk -StoragePool $pool -ErrorAction Stop | ForEach-Object { $_.FriendlyName })
                Write-Field 'Member Disks' $(if ($members.Count -gt 0) { $members -join ', ' } else { 'N/A' })
            } catch { }
            Write-Log ""
        }
    } else {
        Write-Log "  No Storage Spaces pools found"
        Write-Log ""
    }
} catch {
    Write-Log "  Storage Spaces information unavailable: $($_.Exception.Message)"
    Write-Log ""
}

Write-Log "Virtual Disks / RAID:"
try {
    $vdisks = @(Get-VirtualDisk -ErrorAction Stop)
    if ($vdisks.Count -gt 0) {
        foreach ($vd in $vdisks) {
            Write-Log "  Virtual Disk: $($vd.FriendlyName)"
            Write-Field 'Resiliency (RAID)'  (Get-Value $vd.ResiliencySettingName)
            Write-Field 'Data Copies'        (Get-Value $vd.NumberOfDataCopies)
            Write-Field 'Provisioning'       (Get-Value $vd.ProvisioningType)
            Write-Field 'Health Status'      (Get-Value $vd.HealthStatus)
            Write-Field 'Operational Status' ((@($vd.OperationalStatus) | ForEach-Object { "$_" }) -join ', ')
            Write-Field 'Size'               (Format-Size $vd.Size)
            Write-Field 'Footprint on Pool'  (Format-Size $vd.FootprintOnPool)
            Write-Log ""
        }
    } else {
        Write-Log "  No Storage Spaces virtual disks found"
    }
} catch {
    Write-Log "  Virtual disk information unavailable: $($_.Exception.Message)"
}
if ($raidControllers.Count -gt 0) {
    Write-Log "  RAID-capable controller(s) detected: $($raidControllers -join '; ')"
    Write-Log "  (Array type and state are managed by the controller vendor tool.)"
} else {
    Write-Log "  No hardware/firmware RAID controller detected"
}
