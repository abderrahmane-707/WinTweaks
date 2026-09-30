param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

$ci = [System.Globalization.CultureInfo]::InvariantCulture

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

# Formatted line (label: value) with uniform indentation
function Write-Field {
    param ([string]$Label, $Value, [int]$Indent = 2)
    Write-Log ((' ' * $Indent) + ("${Label}:").PadRight(24) + " $Value")
}

# Clean strings: trim whitespace and convert empty/placeholder values to $null
function Convert-CleanString {
    param ($Value)
    $t = "$Value".Trim()
    if ($t -eq '') { return $null }
    if ($t -match '^(Unknown|Undefined|Not Specified|To Be Filled By O\.E\.M\.|None|N/A|Default string|0+|SerNum\d*|PartNum\d*|Manufacturer\d*|Array\d+_PartNumber\d*)$') { return $null }
    return $t
}

function Get-OrNA {
    param ($Value, [string]$Suffix = '')
    if ($null -eq $Value -or "$Value".Trim() -eq '') { return 'N/A' }
    return "$Value$Suffix"
}

# Memory type per SMBIOS specification
function Get-MemoryTypeText {
    param ($Module)
    $map = @{
        18 = 'DDR';   19 = 'DDR2'; 20 = 'DDR2 FB-DIMM'; 24 = 'DDR3'; 26 = 'DDR4'
        27 = 'LPDDR'; 28 = 'LPDDR2'; 29 = 'LPDDR3'; 30 = 'LPDDR4'
        34 = 'DDR5';  35 = 'LPDDR5'
    }
    $code = [int]$Module.SMBIOSMemoryType
    if ($map.ContainsKey($code)) { return $map[$code] }
    if ($code -in 0, 1, 2) { return 'Unknown' }
    return "Code $code"
}

function Get-FormFactorText {
    param ($Code)
    $map = @{
        7  = 'SIMM';           8  = 'DIMM (Desktop)'; 11 = 'RIMM'
        12 = 'SODIMM (Laptop)'; 13 = 'SRIMM';         21 = 'BGA (soldered)'
    }
    $c = [int]$Code
    if ($map.ContainsKey($c)) { return $map[$c] }
    if ($c -in 0, 1, 2) { return 'Unknown' }
    return "Code $c"
}

# Translate JEDEC code to vendor name. The list is partial; the original code is always shown for verification.
function Get-ManufacturerText {
    param ($Raw)
    $clean = Convert-CleanString $Raw
    if (-not $clean) { return 'N/A' }

    if ($clean -match '^([0-9A-Fa-f]{4})(0{0,8})$') {
        $code  = $Matches[1].ToUpper()
        $names = @{
            '80CE' = 'Samsung';   '80AD' = 'SK Hynix'; '802C' = 'Micron'
            '859B' = 'Crucial';   '029E' = 'Corsair';  '04CB' = 'A-DATA'
            '0198' = 'Kingston';  '9801' = 'Kingston'
        }
        if ($names.ContainsKey($code)) { return "$($names[$code]) ($code)" }
        return "Unknown vendor code ($code)"
    }
    return $clean
}

function Get-EccText {
    param ($Code)
    switch ([int]$Code) {
        3 { 'None' }
        4 { 'Parity' }
        5 { 'Single-bit ECC' }
        6 { 'Multi-bit ECC' }
        7 { 'CRC' }
        default { 'Unknown' }
    }
}

# Channel from the slot name or Bank; returns $null if the firmware does not expose it
function Get-ChannelId {
    param ($Module)
    foreach ($text in @("$($Module.DeviceLocator)", "$($Module.BankLabel)")) {
        if ($text -match '(?i)(?:controller[\s_-]*(\d+)[\s_-]*)?channel[\s_-]*([A-D0-9])\b') {
            $id = $Matches[2].ToUpper()
            if ($Matches[1]) { $id = "C$($Matches[1])-$id" }
            return $id
        }
    }
    return $null
}

# Rank from the Attributes field (bits 0-3)
function Get-RankText {
    param ($Module)
    if ($null -eq $Module.Attributes) { return 'N/A' }
    switch ([int]$Module.Attributes -band 0xF) {
        1 { 'Single-rank' }
        2 { 'Dual-rank' }
        4 { 'Quad-rank' }
        8 { 'Octal-rank' }
        default { 'Unknown' }
    }
}

#  Data collection (each query in its own try block)
$os = $null; $cs = $null; $modules = @(); $array = $null; $pageFiles = @(); $pageSettings = @()

try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop }
catch { Write-Log "Error querying operating system memory counters: $($_.Exception.Message)" }

try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
catch { Write-Log "Error querying computer system: $($_.Exception.Message)" }

try { $modules = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Sort-Object DeviceLocator) }
catch { Write-Log "Error querying physical memory modules: $($_.Exception.Message)" }

try {
    $arrays = @(Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction Stop)
    $array  = $arrays | Where-Object { $_.Use -eq 3 } | Select-Object -First 1   # 3 = System Memory
    if (-not $array) { $array = $arrays | Select-Object -First 1 }
} catch { }

try { $pageFiles    = @(Get-CimInstance Win32_PageFileUsage   -ErrorAction Stop) } catch { }
try { $pageSettings = @(Get-CimInstance Win32_PageFileSetting -ErrorAction Stop) } catch { }

$installedBytes = 0.0
if ($modules.Count -gt 0) {
    $installedBytes = [double](($modules | Measure-Object -Property Capacity -Sum).Sum)
}

$totalBytes = 0.0

#  Overview
Write-Log "Memory Information:"
if ($os -and $cs -and $cs.TotalPhysicalMemory -gt 0) {
    $totalBytes = [double]$cs.TotalPhysicalMemory
    $freeBytes  = [double]$os.FreePhysicalMemory * 1KB
    $usedBytes  = $totalBytes - $freeBytes
    $usagePct   = [math]::Round($usedBytes / $totalBytes * 100, 1)

    if ($installedBytes -gt 0) {
        Write-Field 'Installed (modules)' (Format-Size $installedBytes)
    }
    Write-Field 'Usable by Windows' (Format-Size $totalBytes)
    if ($installedBytes -gt $totalBytes) {
        $reserved = $installedBytes - $totalBytes
        Write-Field 'Hardware Reserved' "$([math]::Round($reserved / 1MB, 0)) MB (integrated graphics, firmware, etc.)"
    }
    Write-Field 'Used Memory'      (Format-Size $usedBytes)
    Write-Field 'Available Memory' (Format-Size $freeBytes)
    Write-Field 'Memory Usage'     "$($usagePct.ToString('F1', $ci))%"
} else {
    Write-Log "  Memory counters are not available."
}

#  Current usage breakdown (performance counters via CIM, independent of Windows language)
Write-Log ""
Write-Log "Memory Usage Breakdown:"
try {
    $null = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
    Start-Sleep -Seconds 1     # Second sample to compute rates (Hard Faults)
    $perf = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop

    $standby = [double]$perf.StandbyCacheNormalPriorityBytes + [double]$perf.StandbyCacheReserveBytes + [double]$perf.StandbyCacheCoreBytes
    if ($totalBytes -gt 0) {
        Write-Field 'In Use (excl. cache)' (Format-Size ($totalBytes - [double]$perf.AvailableBytes))
    }
    Write-Field 'Available'          (Format-Size ([double]$perf.AvailableBytes))
    Write-Field 'Cached (system)'    (Format-Size ([double]$perf.CacheBytes))
    Write-Field 'Standby'            (Format-Size $standby)
    Write-Field 'Modified'           (Format-Size ([double]$perf.ModifiedPageListBytes))
    Write-Field 'Free (zeroed)'      (Format-Size ([double]$perf.FreeAndZeroPageListBytes))
    Write-Field 'Paged Pool'         (Format-Size ([double]$perf.PoolPagedBytes))
    Write-Field 'Non-Paged Pool'     (Format-Size ([double]$perf.PoolNonpagedBytes))
    Write-Field 'Hard Faults (Pages/s)' ([double]$perf.PagesInputPersec).ToString('F0', $ci)
} catch {
    Write-Log "  Performance counters are not available: $($_.Exception.Message)"
}

# Memory compression
try {
    $mm = Get-MMAgent -ErrorAction Stop
    Write-Field 'Memory Compression' $(if ($mm.MemoryCompression) { 'Enabled' } else { 'Disabled' })
    $mc = Get-Process -Name 'Memory Compression' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mc) { Write-Field 'Compressed Store' (Format-Size ([double]$mc.WorkingSet64)) }
} catch { }

# Slots, maximum capacity, and error correction type
if ($array) {
    Write-Log ""
    Write-Log "Motherboard Memory Capabilities:"
    $slotsTotal = [int]$array.MemoryDevices
    $slotsUsed  = $modules.Count
    if ($slotsTotal -gt 0) {
        Write-Field 'Slots (used / total)' "$slotsUsed / $slotsTotal"
    }
    $maxKB = if ($array.MaxCapacityEx) { [double]$array.MaxCapacityEx } else { [double]$array.MaxCapacity }
    if ($maxKB -gt 0) {
        Write-Field 'Max Supported' "$([math]::Round($maxKB / 1MB, 0)) GB"
    }
    Write-Field 'Error Correction' (Get-EccText $array.MemoryErrorCorrection)
}

#  Virtual memory and page file
Write-Log ""
Write-Log "Commit Memory (RAM + Page File):"
if ($os) {
    $commitLimit = [double]$os.TotalVirtualMemorySize * 1KB
    $commitFree  = [double]$os.FreeVirtualMemory * 1KB
    $commitUsed  = $commitLimit - $commitFree

    Write-Field 'Commit Limit'     (Format-Size $commitLimit)
    Write-Field 'Commit Used'      (Format-Size $commitUsed)
    Write-Field 'Commit Available' (Format-Size $commitFree)

    if ($commitLimit -gt 0) {
        $commitPct = [math]::Round($commitUsed / $commitLimit * 100, 1)
        Write-Field 'Commit Usage' "$($commitPct.ToString('F1', $ci))%"
    }
} else {
    Write-Log "  Commit counters are not available."
}

Write-Log ""
Write-Log "Page File:"
if ($cs) {
    Write-Field 'Managed Automatically' $(if ($cs.AutomaticManagedPagefile) { 'Yes' } else { 'No' })
}
if ($pageFiles.Count -gt 0) {
    foreach ($pf in $pageFiles) {
        Write-Log "  $($pf.Name)"
        Write-Field 'Allocated' "$($pf.AllocatedBaseSize) MB" 4
        Write-Field 'Current Usage' "$($pf.CurrentUsage) MB" 4
        Write-Field 'Peak Usage' "$($pf.PeakUsage) MB" 4

        $setting = $pageSettings | Where-Object { $_.Name -eq $pf.Name } | Select-Object -First 1
        if ($setting) {
            Write-Field 'Configured Initial/Max' "$($setting.InitialSize) MB / $($setting.MaximumSize) MB" 4
        }
    }
} else {
    Write-Log "  No page file configured."
}

#  Modules
Write-Log ""
Write-Log "Memory Modules:"
if ($modules.Count -gt 0) {
    foreach ($module in $modules) {
        $rated  = if ($module.Speed) { [int]$module.Speed } else { $null }
        $actual = if ($module.ConfiguredClockSpeed) { [int]$module.ConfiguredClockSpeed } else { $null }
        $volt   = if ($module.ConfiguredVoltage -and $module.ConfiguredVoltage -gt 0) {
            "$(([double]$module.ConfiguredVoltage / 1000).ToString('F2', $ci)) V"
        } else { 'N/A' }
        $voltRange = if ($module.MinVoltage -gt 0 -and $module.MaxVoltage -gt 0) {
            "$(([double]$module.MinVoltage / 1000).ToString('F2', $ci)) V / $(([double]$module.MaxVoltage / 1000).ToString('F2', $ci)) V"
        } else { 'N/A' }
        $widthText = if ($module.DataWidth -and $module.TotalWidth) { "$($module.DataWidth) / $($module.TotalWidth) bits" } else { 'N/A' }
        $eccActual = if ($module.DataWidth -and $module.TotalWidth) {
            if ([int]$module.TotalWidth -gt [int]$module.DataWidth) { 'Yes (ECC)' } else { 'No' }
        } else { 'N/A' }
        $chan = Get-ChannelId $module

        $slotName = Get-OrNA (Convert-CleanString $module.DeviceLocator)
        Write-Log "  Slot ${slotName}:"
        Write-Field 'Bank'           (Get-OrNA (Convert-CleanString $module.BankLabel)) 4
        Write-Field 'Channel'        $(if ($chan) { $chan } else { 'Unknown' }) 4
        Write-Field 'Manufacturer'   (Get-ManufacturerText $module.Manufacturer) 4
        Write-Field 'Part Number'    (Get-OrNA (Convert-CleanString $module.PartNumber)) 4
        Write-Field 'Serial Number'  (Get-OrNA (Convert-CleanString $module.SerialNumber)) 4
        Write-Field 'Capacity'       (Format-Size $module.Capacity) 4
        Write-Field 'Type'           (Get-MemoryTypeText $module) 4
        Write-Field 'Form Factor'    (Get-FormFactorText $module.FormFactor) 4
        Write-Field 'Rank'           (Get-RankText $module) 4
        Write-Field 'Data / Total Width' $widthText 4
        Write-Field 'ECC (actual)'   $eccActual 4
        Write-Field 'Rated Speed'    $(if ($rated) { "$rated MT/s" } else { 'N/A' }) 4
        Write-Field 'Running Speed'  $(if ($actual) { "$actual MT/s" } else { 'N/A' }) 4
        Write-Field 'Voltage'        $volt 4
        Write-Field 'Min / Max Voltage' $voltRange 4

        if ($rated -and $actual -and $actual -lt $rated) {
            Write-Log "    Note: running below rated speed; XMP/DOCP may be disabled in BIOS."
        }
        Write-Log ""
    }
} else {
    Write-Log "  No memory module information available"
}
