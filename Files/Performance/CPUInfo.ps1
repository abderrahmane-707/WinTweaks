param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Return "N/A" for empty values
function Get-Value {
    param ($Value, [string]$Suffix = '')
    if ($null -eq $Value -or "$Value".Trim() -eq '') { return 'N/A' }
    return "$("$Value".Trim())$Suffix"
}

# Convert boolean values to Yes/No
function Get-YesNo {
    param ($Value)
    if ($null -eq $Value) { return 'N/A' }
    if ($Value) { return 'Yes' } else { return 'No' }
}

# Convert architecture number to name
function Get-ArchitectureName {
    param ($Code)
    switch ($Code) {
        0       { 'x86' }
        1       { 'MIPS' }
        2       { 'Alpha' }
        3       { 'PowerPC' }
        5       { 'ARM' }
        6       { 'Itanium (ia64)' }
        9       { 'x64' }
        12      { 'ARM64' }
        default { 'N/A' }
    }
}

# Convert UpgradeMethod number to socket type
function Get-SocketTypeName {
    param ($Code)
    $map = @{
        3 = 'Daughter Board'; 4 = 'ZIF Socket'; 6 = 'None'
        8 = 'Slot 1'; 9 = 'Slot 2'; 10 = 'Socket 370'
        15 = 'Socket 478'; 16 = 'Socket 754'; 17 = 'Socket 940'; 18 = 'Socket 939'
        19 = 'Socket mPGA604'; 20 = 'Socket LGA771'; 21 = 'Socket LGA775'
        23 = 'Socket AM2'; 24 = 'Socket F (1207)'; 25 = 'Socket LGA1366'
        26 = 'Socket G34'; 27 = 'Socket AM3'; 28 = 'Socket C32'
        29 = 'Socket LGA1156'; 30 = 'Socket LGA1567'
        36 = 'Socket LGA1155'; 37 = 'Socket LGA1356'; 38 = 'Socket LGA2011'
        41 = 'Socket FM1'; 42 = 'Socket FM2'; 43 = 'Socket LGA2011-3'
        45 = 'Socket LGA1150'; 49 = 'Socket AM4'; 50 = 'Socket LGA1151'
        54 = 'Socket LGA3647-1'; 55 = 'Socket SP3'; 56 = 'Socket SP3r2'
        57 = 'Socket LGA2066'
    }
    if ($null -eq $Code) { return 'N/A' }
    if ($map.ContainsKey([int]$Code)) { return $map[[int]$Code] }
    return "Other (code $Code)"
}

# Calculate voltage from CurrentVoltage / VoltageCaps
function Get-VoltageText {
    param ($CurrentVoltage, $VoltageCaps)
    if ($null -ne $CurrentVoltage -and ($CurrentVoltage -band 0x80)) {
        # Bit 7 set: value is in tenths of a volt
        return "{0:N1} V" -f ((($CurrentVoltage -band 0x7F)) / 10)
    }
    if ($null -ne $VoltageCaps) {
        $caps = @()
        if ($VoltageCaps -band 1) { $caps += '5.0 V' }
        if ($VoltageCaps -band 2) { $caps += '3.3 V' }
        if ($VoltageCaps -band 4) { $caps += '2.9 V' }
        if ($caps.Count -gt 0) { return ($caps -join ' / ') }
    }
    return 'N/A'
}

# Extract Family / Model / Stepping from Description
function Get-CpuIdentity {
    param ([string]$Description)
    $result = @{ Family = 'N/A'; Model = 'N/A'; Stepping = 'N/A' }
    if ($Description -match 'Family\s+(\d+)\s+Model\s+(\d+)\s+Stepping\s+(\d+)') {
        $result.Family   = $Matches[1]
        $result.Model    = $Matches[2]
        $result.Stepping = $Matches[3]
    }
    return $result
}

# Total cache size for a specific level from Win32_CacheMemory (KB)
# Level: 3 = L1, 4 = L2, 5 = L3
function Get-CacheTotalKB {
    param ($CacheEntries, [int]$Level)
    $entries = @($CacheEntries | Where-Object { $_.Level -eq $Level })
    if ($entries.Count -eq 0) { return $null }
    return ($entries | Measure-Object -Property InstalledSize -Sum).Sum
}

# Properties to retrieve
$properties = @(
    'DeviceID', 'Manufacturer', 'Name', 'Description', 'AddressWidth',
    'NumberOfCores', 'NumberOfLogicalProcessors', 'CurrentClockSpeed',
    'MaxClockSpeed', 'L2CacheSize', 'L3CacheSize', 'ProcessorId',
    'SocketDesignation', 'LoadPercentage', 'Status',
    'Architecture', 'NumberOfEnabledCore', 'ThreadCount',
    'VirtualizationFirmwareEnabled', 'SecondLevelAddressTranslationExtensions',
    'VMMonitorModeExtensions', 'ExtClock', 'VoltageCaps', 'CurrentVoltage',
    'PartNumber', 'SerialNumber', 'UpgradeMethod', 'Family', 'Stepping'
)

# Retrieve processor information via CIM
try {
    $cpuInstances = Get-CimInstance -ClassName Win32_Processor -Property $properties -ErrorAction Stop

    # L1 cache from Win32_CacheMemory (may not be available on all devices)
    $cacheEntries = $null
    try {
        $cacheEntries = Get-CimInstance -ClassName Win32_CacheMemory -ErrorAction Stop
    } catch { }

    if ($cpuInstances) {
        foreach ($cpuInfo in $cpuInstances) {

            $identity = Get-CpuIdentity $cpuInfo.Description
            $l1Total  = Get-CacheTotalKB $cacheEntries 3

            Write-Log "Processor Details ($($cpuInfo.DeviceID))"
            Write-Log " Manufacturer:         $(Get-Value $cpuInfo.Manufacturer)"
            Write-Log " Name:                 $(Get-Value $cpuInfo.Name)"
            Write-Log " Description:          $(Get-Value $cpuInfo.Description)"
            Write-Log " Family:               $($identity.Family)"
            Write-Log " Model:                $($identity.Model)"
            Write-Log " Stepping:             $($identity.Stepping)"

            Write-Log "`nArchitecture And Specifications:"
            Write-Log " Architecture:        $(Get-ArchitectureName $cpuInfo.Architecture)"
            Write-Log " Address Width:       $(Get-Value $cpuInfo.AddressWidth '-bit')"
            Write-Log " Cores:               $(Get-Value $cpuInfo.NumberOfCores)"
            Write-Log " Enabled Cores:       $(Get-Value $cpuInfo.NumberOfEnabledCore)"
            Write-Log " Logical Processors:  $(Get-Value $cpuInfo.NumberOfLogicalProcessors)"
            Write-Log " Thread Count:        $(Get-Value $cpuInfo.ThreadCount)"

            Write-Log "`nVirtualization Support:"
            Write-Log " Virtualization Enabled (BIOS): $(Get-YesNo $cpuInfo.VirtualizationFirmwareEnabled)"
            Write-Log " SLAT Support:                  $(Get-YesNo $cpuInfo.SecondLevelAddressTranslationExtensions)"
            Write-Log " VM Monitor Extensions:         $(Get-YesNo $cpuInfo.VMMonitorModeExtensions)"

            Write-Log "`nClock Speed:"
            Write-Log " Current Clock:       $(Get-Value $cpuInfo.CurrentClockSpeed ' MHz')"
            Write-Log " Max Clock Speed:     $(Get-Value $cpuInfo.MaxClockSpeed ' MHz')"
            Write-Log " Bus Speed (ExtClock): $(Get-Value $cpuInfo.ExtClock ' MHz')"

            Write-Log "`nCache Information:"
            Write-Log " L1 Cache Size (total): $(Get-Value $l1Total ' KB')"
            Write-Log " L2 Cache Size:       $(Get-Value $cpuInfo.L2CacheSize ' KB')"
            Write-Log " L3 Cache Size:       $(Get-Value $cpuInfo.L3CacheSize ' KB')"

            Write-Log "`nPower:"
            Write-Log " Voltage:             $(Get-VoltageText $cpuInfo.CurrentVoltage $cpuInfo.VoltageCaps)"

            Write-Log "`nStatus And Identification:"
            Write-Log " Device ID:           $(Get-Value $cpuInfo.DeviceID)"
            Write-Log " Processor ID:        $(Get-Value $cpuInfo.ProcessorId)"
            Write-Log " Part Number:         $(Get-Value $cpuInfo.PartNumber)"
            Write-Log " Serial Number:       $(Get-Value $cpuInfo.SerialNumber)"
            Write-Log " Socket Designation:  $(Get-Value $cpuInfo.SocketDesignation)"
            Write-Log " Socket Type:         $(Get-SocketTypeName $cpuInfo.UpgradeMethod)"

            Write-Log "`nLoad And Status:"
            Write-Log " Current Load:        $(Get-Value $cpuInfo.LoadPercentage '%')"
            Write-Log " Status:              $(Get-Value $cpuInfo.Status)"
        }

    } else {
        Write-Log " No processor information found on this system."
    }
} catch {
    Write-Log " Error retrieving processor information: $($_.Exception.Message)"
}
