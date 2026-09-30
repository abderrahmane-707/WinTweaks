param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Return "N/A" for empty values
function Get-Value {
    param ($Value, [string]$Suffix = '')
    $text = "$Value".Trim()
    if ($null -eq $Value -or $text -eq '') { return 'N/A' }
    return "$text$Suffix"
}

# Convert driver date to readable text (supports DateTime or raw WMI string)
function Convert-DriverDate {
    param ($RawDate)
    if (-not $RawDate) { return $null }
    if ($RawDate -is [datetime]) { return $RawDate.ToString('yyyy-MM-dd') }
    try {
        return [System.Management.ManagementDateTimeConverter]::ToDateTime($RawDate).ToString('yyyy-MM-dd')
    } catch {
        return "$RawDate"
    }
}

# Convert a byte array (REG_BINARY) to UInt64 after padding to 8 bytes
function ConvertTo-UInt64Safe {
    param ($Value)
    if ($Value -is [byte[]]) {
        $padded = New-Object byte[] 8
        [Array]::Copy($Value, $padded, [Math]::Min($Value.Length, 8))
        return [BitConverter]::ToUInt64($padded, 0)
    }
    return [uint64][double]$Value
}

# Convert a registry string value (may be REG_BINARY) to text
function Convert-RegString {
    param ($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [byte[]]) {
        if ($Value.Length -ge 2 -and $Value[1] -eq 0) {
            $s = [System.Text.Encoding]::Unicode.GetString($Value)
        } else {
            $s = [System.Text.Encoding]::ASCII.GetString($Value)
        }
        return ($s -replace "`0", '').Trim()
    }
    return "$Value".Trim()
}

# Read a property from Get-PnpDeviceProperty without aborting the script on failure
function Get-PnpProp {
    param ([string]$InstanceId, [string]$Key)
    if (-not $InstanceId) { return $null }
    try {
        return (Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName $Key -ErrorAction Stop).Data
    } catch {
        return $null
    }
}

# Determine the GPU type (integrated / discrete / virtual)
function Get-GpuType {
    param ($Name)
    if (-not $Name) { return 'Unknown' }
    if ($Name -match 'Microsoft Basic|Remote|Virtual|VMware|Hyper-V|Parsec|QXL|VirtualBox') { return 'Virtual/Generic' }
    if ($Name -match 'Intel.*Arc.*\bA\d{3}') { return 'Discrete' }
    if ($Name -match 'Intel.*(UHD|HD Graphics|Iris|Xe|Arc.*Graphics)|Radeon(\(TM\))?\s+(Graphics|Vega)|Radeon\s+\d{3}M\b|AMD Radeon\(TM\) Graphics') { return 'Integrated' }
    return 'Discrete'
}

# Translate the Device Manager error code
function Get-ErrorText {
    param ($Code)
    if ($null -eq $Code) { return 'N/A' }
    $map = @{
        0  = 'Working properly'
        1  = 'Device is not configured correctly'
        3  = 'Driver may be corrupted or system is low on memory'
        10 = 'Device cannot start'
        12 = 'Device cannot find enough free resources'
        14 = 'Device requires a restart'
        18 = 'Reinstall the drivers for this device'
        22 = 'Device is disabled'
        24 = 'Device is not present or not working properly'
        28 = 'Drivers are not installed'
        31 = 'Device is not working properly (cannot load drivers)'
        32 = 'Driver (service) is disabled'
        37 = 'Driver returned a failure from its initialization routine'
        39 = 'Driver may be corrupted or missing'
        41 = 'Windows loaded the driver but cannot find the device'
        43 = 'Windows stopped this device (reported problems)'
        45 = 'Device is not currently connected'
        48 = 'Driver blocked from starting (known compatibility issue)'
        52 = 'Windows cannot verify the digital signature of the driver'
    }
    $c = [int]$Code
    if ($map.ContainsKey($c)) { return "$c - $($map[$c])" }
    return "Error code $c"
}

# Vendor name from Vendor ID
function Get-VendorName {
    param ([string]$VendorId)
    switch ($VendorId) {
        '10DE' { 'NVIDIA' }
        '1002' { 'AMD' }
        '1022' { 'AMD' }
        '8086' { 'Intel' }
        '1414' { 'Microsoft' }
        '15AD' { 'VMware' }
        '80EE' { 'VirtualBox' }
        default { $null }
    }
}

# Fetch the GPU driver key from the Display Class (used for memory, VBIOS, etc.)
function Get-GpuRegistryProps {
    param ($Gpu)

    $classPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    try {
        $keys = Get-ChildItem -Path $classPath -ErrorAction Stop |
            Where-Object { $_.PSChildName -match '^\d{4}$' }
    } catch { return $null }

    $fallback = $null
    foreach ($key in $keys) {
        $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
        if (-not $props) { continue }

        # 1) Most precise: DeviceInstanceID (available on modern Windows 10)
        if ($props.DeviceInstanceID -and $Gpu.PNPDeviceID -and
            $props.DeviceInstanceID -eq $Gpu.PNPDeviceID) {
            return $props
        }

        # 2) MatchingDeviceId within PNPDeviceID
        if (-not $fallback -and $props.MatchingDeviceId -and $Gpu.PNPDeviceID -and
            $Gpu.PNPDeviceID -like "*$($props.MatchingDeviceId)*") {
            $fallback = $props
        }

        # 3) Description matching (DriverDesc) as last resort
        if (-not $fallback -and $props.DriverDesc -and $Gpu.Name -and
            (Convert-RegString $props.DriverDesc) -eq $Gpu.Name) {
            $fallback = $props
        }
    }
    return $fallback
}

# Read the real dedicated video memory (64-bit), falling back to AdapterRAM
function Get-VideoMemoryMB {
    param ($Gpu, $RegProps, $DxDedicatedBytes)

    if ($RegProps) {
        $mem = $RegProps.'HardwareInformation.qwMemorySize'
        if ($null -eq $mem) { $mem = $RegProps.'HardwareInformation.MemorySize' }
        if ($mem) {
            try { return [math]::Round([double](ConvertTo-UInt64Safe $mem) / 1MB, 0) } catch { }
        }
    }
    if ($DxDedicatedBytes -and [double]$DxDedicatedBytes -gt 0) {
        return [math]::Round([double]$DxDedicatedBytes / 1MB, 0)
    }
    if ($null -ne $Gpu.AdapterRAM -and $Gpu.AdapterRAM -gt 0) {
        return [math]::Round($Gpu.AdapterRAM / 1MB, 0)
    }
    return $null
}

# DirectX from the Registry
function Format-MemoryMB {
    param ($Bytes)
    if ($null -eq $Bytes -or [double]$Bytes -le 0) { return $null }
    return "$([math]::Round([double]$Bytes / 1MB, 0)) MB"
}

function ConvertTo-FeatureLevelText {
    param ($Value)
    if ($null -eq $Value) { return $null }
    $map = @{
        0x9100 = '9_1';  0x9200 = '9_2';  0x9300 = '9_3'
        0xa000 = '10_0'; 0xa100 = '10_1'
        0xb000 = '11_0'; 0xb100 = '11_1'
        0xc000 = '12_0'; 0xc100 = '12_1'; 0xc200 = '12_2'
    }
    $v = [int]$Value
    if ($map.ContainsKey($v)) { return $map[$v] }
    return ('0x{0:X}' -f $v)
}

function Get-DirectXAdapters {
    $list = @()
    try {
        $keys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction Stop
    } catch { return $list }

    foreach ($k in $keys) {
        $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
        if (-not $p -or -not $p.Description) { continue }
        $list += [PSCustomObject]@{
            Description          = "$($p.Description)".Trim()
            VendorId             = if ($null -ne $p.VendorId) { '{0:X4}' -f [int]$p.VendorId } else { $null }
            DeviceId             = if ($null -ne $p.DeviceId) { '{0:X4}' -f [int]$p.DeviceId } else { $null }
            DedicatedVideoMemory = $p.DedicatedVideoMemory
            SharedSystemMemory   = $p.SharedSystemMemory
            MaxD3D12FeatureLevel = $p.MaxD3D12FeatureLevel
        }
    }
    return $list
}

# Presence of the DirectX 12 library (the actual supported version per GPU appears in Feature Level)
function Get-DirectXRuntimeInfo {
    $dll = Join-Path $env:windir 'System32\d3d12.dll'
    if (Test-Path $dll) {
        $v = $null
        # FileVersion has an additional tag like (WinBuild.160101.0800); take the number only
        try { $v = ((Get-Item $dll).VersionInfo.FileVersion -split '\s+')[0] } catch { }
        return "DirectX 12 runtime installed ($v)"
    }
    if (Test-Path (Join-Path $env:windir 'System32\d3d11.dll')) { return 'DirectX 11 runtime only' }
    return 'Unknown'
}

# Legacy version from the registry (does not reflect DirectX 12, for comparison only)
function Get-DirectXRegistryVersion {
    try {
        $dx = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction Stop
        if ($dx.Version) { return $dx.Version }
    } catch { }
    return 'Unknown'
}

# Hardware-Accelerated GPU Scheduling
function Get-HwSchedulingStatus {
    try {
        $v = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction Stop).HwSchMode
        switch ([int]$v) {
            2 { return 'Enabled' }
            1 { return 'Disabled' }
            default { return "Unknown ($v)" }
        }
    } catch {
        return 'Not supported / not configured'
    }
}

# Variable Refresh Rate (VRR) optimization for windowed games
function Get-VrrOptimizeStatus {
    try {
        $v = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' -Name 'DirectXUserGlobalSettings' -ErrorAction Stop).DirectXUserGlobalSettings
        if ($v -match 'VRROptimizeEnable=(\d)') {
            if ($Matches[1] -eq '1') { return 'Enabled' } else { return 'Disabled' }
        }
    } catch { }
    return 'Not configured'
}

# Vulkan
function Get-VulkanInfo {
    $loader = Join-Path $env:windir 'System32\vulkan-1.dll'
    $info = [ordered]@{ LoaderPresent = (Test-Path $loader); LoaderVersion = $null; Drivers = @() }
    if ($info.LoaderPresent) {
        try { $info.LoaderVersion = (Get-Item $loader).VersionInfo.ProductVersion } catch { }
    }
    foreach ($p in 'HKLM:\SOFTWARE\Khronos\Vulkan\Drivers', 'HKLM:\SOFTWARE\WOW6432Node\Khronos\Vulkan\Drivers') {
        try {
            $item = Get-Item -Path $p -ErrorAction Stop
            $info.Drivers += $item.GetValueNames()
        } catch { }
    }
    $info.Drivers = @($info.Drivers | Select-Object -Unique)
    return [PSCustomObject]$info
}

# OpenCL and CUDA
function Get-ComputeInfo {
    $sys32 = Join-Path $env:windir 'System32'
    $cudaDll   = Join-Path $sys32 'nvcuda.dll'
    $openclDll = Join-Path $sys32 'OpenCL.dll'

    $cudaVer = $null
    if (Test-Path $cudaDll) { try { $cudaVer = (Get-Item $cudaDll).VersionInfo.FileVersion } catch { } }

    $oclVer = $null
    if (Test-Path $openclDll) { try { $oclVer = (Get-Item $openclDll).VersionInfo.FileVersion } catch { } }

    $oclVendors = @()
    try {
        $oclVendors = @((Get-Item -Path 'HKLM:\SOFTWARE\Khronos\OpenCL\Vendors' -ErrorAction Stop).GetValueNames())
    } catch { }

    [PSCustomObject]@{
        CudaAvailable    = (Test-Path $cudaDll)
        CudaDriverDll    = $cudaVer
        OpenCLAvailable  = (Test-Path $openclDll)
        OpenCLLoader     = $oclVer
        OpenCLVendors    = $oclVendors
    }
}

# Connected monitors
function ConvertTo-MonitorText {
    param ($Codes)
    if (-not $Codes) { return $null }
    return (-join ($Codes | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ })).Trim()
}

function Get-MonitorInfo {
    $list = @()
    try {
        $ids    = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID -ErrorAction Stop)
        $params = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue)
    } catch {
        Write-Log "Unable to query WmiMonitorID: $($_.Exception.Message)"
        return @()
    }

    foreach ($m in $ids) {
        $p = $params | Where-Object { $_.InstanceName -eq $m.InstanceName } | Select-Object -First 1
        $sizeText = $null
        if ($p -and $p.MaxHorizontalImageSize -and $p.MaxVerticalImageSize) {
            $h = [double]$p.MaxHorizontalImageSize
            $v = [double]$p.MaxVerticalImageSize
            $diag = [math]::Round([math]::Sqrt($h * $h + $v * $v) / 2.54, 1)
            $sizeText = "$diag inch ($($p.MaxHorizontalImageSize) x $($p.MaxVerticalImageSize) cm)"
        }
        $list += [PSCustomObject]@{
            Name         = Get-Value $(
                $fn = ConvertTo-MonitorText $m.UserFriendlyName
                if ($fn) { $fn } else {
                    ('{0} {1} (generic name)' -f (ConvertTo-MonitorText $m.ManufacturerName), (ConvertTo-MonitorText $m.ProductCodeID)).Trim()
                }
            )
            Manufacturer = Get-Value (ConvertTo-MonitorText $m.ManufacturerName)
            ProductCode  = Get-Value (ConvertTo-MonitorText $m.ProductCodeID)
            Serial       = Get-Value (ConvertTo-MonitorText $m.SerialNumberID)
            YearOfManufacture = Get-Value $m.YearOfManufacture
            Size         = Get-Value $sizeText
            Active       = $m.Active
        }
    }
    return $list
}

# Latest GPU errors from the event log
function Get-GpuEvents {
    $providers = 'nvlddmkm', 'Display', 'amdkmdag', 'amdwddmg', 'igfx', 'igfxn', 'Microsoft-Windows-Display'
    $start = (Get-Date).AddDays(-30)
    $result = [ordered]@{ TdrCount30d = 0; Recent = @() }

    try {
        $tdr = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'; ProviderName = $providers; Id = 4101; StartTime = $start
        } -ErrorAction SilentlyContinue)
        $result.TdrCount30d = $tdr.Count
    } catch { }

    try {
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'; ProviderName = $providers; Level = 1, 2, 3; StartTime = $start
        } -MaxEvents 5 -ErrorAction SilentlyContinue)
        foreach ($e in $events) {
            $msg = ("$($e.Message)" -replace '\s+', ' ').Trim()
            if ($msg.Length -gt 140) { $msg = $msg.Substring(0, 140) + '...' }
            $result.Recent += [PSCustomObject]@{
                Time     = $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                Provider = $e.ProviderName
                EventId  = $e.Id
                Level    = $e.LevelDisplayName
                Message  = $msg
            }
        }
    } catch { }

    return [PSCustomObject]$result
}

# Collect GPU information
function Get-GPUInfo {
    param ($DxAdapters)

    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop)
    } catch {
        Write-Log "Unable to query Win32_VideoController: $($_.Exception.Message)"
        return @()
    }

    try {
        $drivers = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -Filter "DeviceClass = 'DISPLAY'" -ErrorAction Stop)
    } catch {
        Write-Log "Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        $drivers = @()
    }

    foreach ($g in $gpus) {
        $matchingDriver = $null

        if ($drivers.Count -gt 0) {
            # 1) Match by PNPDeviceID
            if ($g.PNPDeviceID) {
                $matchingDriver = $drivers |
                    Where-Object { $_.DeviceID -eq $g.PNPDeviceID } |
                    Select-Object -First 1
            }
            # 2) Match by name (independent, works even if PNPDeviceID is empty)
            if (-not $matchingDriver -and $g.Name) {
                $matchingDriver = $drivers |
                    Where-Object { $_.DeviceName -eq $g.Name } |
                    Select-Object -First 1
            }
        }

        $regProps   = Get-GpuRegistryProps $g
        $rawDate    = if ($matchingDriver -and $matchingDriver.DriverDate) { $matchingDriver.DriverDate } else { $g.DriverDate }
        $driverDate = Convert-DriverDate $rawDate

        # DirectX data from the registry (match by Vendor/Device then by name)
        $dx = $null
        if ($DxAdapters -and $DxAdapters.Count -gt 0) {
            if ($g.PNPDeviceID -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})') {
                $vid = $Matches[1]; $did = $Matches[2]
                $dx = $DxAdapters | Where-Object { $_.VendorId -eq $vid -and $_.DeviceId -eq $did } | Select-Object -First 1
            }
            if (-not $dx -and $g.Name) {
                $dx = $DxAdapters | Where-Object { $_.Description -eq $g.Name } | Select-Object -First 1
            }
        }

        $ramMB      = Get-VideoMemoryMB $g $regProps $(if ($dx) { $dx.DedicatedVideoMemory })

        # Vendor / Device ID
        $vendorId = $null; $deviceId = $null; $subsys = $null
        if ($g.PNPDeviceID -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})') {
            $vendorId = $Matches[1]; $deviceId = $Matches[2]
        }
        if ($g.PNPDeviceID -match 'SUBSYS_([0-9A-F]{8})') { $subsys = $Matches[1] }

        # Resolution and refresh rate (ignore inactive adapters)
        $isActive   = [bool]($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution)
        $currentRes = $null
        if ($isActive) { $currentRes = "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)" }

        $refresh = if ($g.CurrentRefreshRate) { "$($g.CurrentRefreshRate) Hz" } else { $null }
        $maxRefresh = if ($g.MaxRefreshRate) { "$($g.MaxRefreshRate) Hz" } else { $null }
        $bpp = if ($g.CurrentBitsPerPixel) { "$($g.CurrentBitsPerPixel) bit" } else { $null }

        # PCI location and install date
        $location    = Get-PnpProp $g.PNPDeviceID 'DEVPKEY_Device_LocationInfo'
        $installDate = Get-PnpProp $g.PNPDeviceID 'DEVPKEY_Device_InstallDate'
        $installText = if ($installDate -is [datetime]) { $installDate.ToString('yyyy-MM-dd') } else { $null }

        # Signature status
        $signedText = $null
        if ($matchingDriver) {
            $signedText = if ($matchingDriver.IsSigned) { 'Signed' } else { 'Not signed' }
        }

        [PSCustomObject]@{
            Index                = Get-Value $g.DeviceID
            Name                 = Get-Value $g.Name
            Type                 = Get-GpuType $g.Name
            IsPrimary            = 'No'
            DisplayActive        = if ($isActive) { 'Yes' } else { 'No' }
            VideoProcessor       = Get-Value $g.VideoProcessor
            AdapterCompatibility = Get-Value $g.AdapterCompatibility
            VendorId             = Get-Value $vendorId
            VendorName           = Get-Value (Get-VendorName $vendorId)
            DeviceIdHex          = Get-Value $deviceId
            SubsystemId          = Get-Value $subsys
            PciLocation          = Get-Value $location
            Status               = Get-Value $g.Status
            ErrorCode            = Get-ErrorText $g.ConfigManagerErrorCode
            ErrorCodeRaw         = $g.ConfigManagerErrorCode
            AdapterRAM           = Get-Value $ramMB ' MB'
            SharedMemory         = Get-Value $(if ($dx) { Format-MemoryMB $dx.SharedSystemMemory })
            ChipType             = Get-Value (Convert-RegString $(if ($regProps) { $regProps.'HardwareInformation.ChipType' }))
            DacType              = Get-Value (Convert-RegString $(if ($regProps) { $regProps.'HardwareInformation.DACType' }))
            AdapterString        = Get-Value (Convert-RegString $(if ($regProps) { $regProps.'HardwareInformation.AdapterString' }))
            VBios                = Get-Value (Convert-RegString $(if ($regProps) { $regProps.'HardwareInformation.BiosString' }))
            OpenGLDriver         = Get-Value (Convert-RegString $(if ($regProps) { $regProps.OpenGLDriverName }))
            CurrentResolution    = Get-Value $currentRes
            RefreshRate          = Get-Value $refresh
            MaxRefreshRate       = Get-Value $maxRefresh
            BitsPerPixel         = Get-Value $bpp
            VideoModeDescription = Get-Value $g.VideoModeDescription
            DriverVersion        = Get-Value $g.DriverVersion
            DriverDate           = Get-Value $driverDate
            DriverInstallDate    = Get-Value $installText
            DriverProvider       = Get-Value $(if ($matchingDriver) { $matchingDriver.DriverProviderName })
            DriverSigned         = Get-Value $signedText
            DriverSigner         = Get-Value $(if ($matchingDriver) { $matchingDriver.Signer })
            InfName              = Get-Value $(if ($matchingDriver) { $matchingDriver.InfName })
            MaxFeatureLevel      = Get-Value $(if ($dx) { ConvertTo-FeatureLevelText $dx.MaxD3D12FeatureLevel })
        }
    }
}

# Execution
$dxAdapters = @(Get-DirectXAdapters)
$gpuInfo    = @(Get-GPUInfo -DxAdapters $dxAdapters)

# Determine the primary GPU (most likely): first adapter with an active current resolution
$primary = $gpuInfo | Where-Object { $_.DisplayActive -eq 'Yes' } | Select-Object -First 1
if ($primary) { $primary.IsPrimary = 'Yes (likely)' }

# Detect hybrid graphics (Optimus / AMD Switchable)
$hasIntegrated = @($gpuInfo | Where-Object { $_.Type -eq 'Integrated' }).Count -gt 0
$hasDiscrete   = @($gpuInfo | Where-Object { $_.Type -eq 'Discrete' }).Count -gt 0
$hybrid = if ($hasIntegrated -and $hasDiscrete) { 'Yes (integrated + discrete detected)' } else { 'No' }

$sysInfo = [PSCustomObject]@{
    DirectXVersion      = Get-DirectXRuntimeInfo
    DirectXRegistry     = Get-DirectXRegistryVersion
    HwScheduling        = Get-HwSchedulingStatus
    VrrWindowedGames    = Get-VrrOptimizeStatus
    Vulkan              = Get-VulkanInfo
    Compute             = Get-ComputeInfo
    HybridGraphics      = $hybrid
    Monitors            = @(Get-MonitorInfo)
    Events              = Get-GpuEvents
}

if ($gpuInfo.Count -gt 0) {
    $i = 1
    foreach ($g in $gpuInfo) {
        Write-Log "GPU #$i - $($g.Name)"

        Write-Log " Basic Information:"
        Write-Log "  Name:                    $($g.Name)"
        Write-Log "  Type:                    $($g.Type)"
        Write-Log "  Primary Adapter:         $($g.IsPrimary)"
        Write-Log "  Display Output Active:   $($g.DisplayActive)"
        Write-Log "  Video Processor:         $($g.VideoProcessor)"
        Write-Log "  Manufacturer:            $($g.AdapterCompatibility)"
        Write-Log "  Status:                  $($g.Status)"
        Write-Log "  Device Error Code:       $($g.ErrorCode)"

        Write-Log "`n Hardware Identifiers:"
        Write-Log "  Vendor ID:               $($g.VendorId) ($($g.VendorName))"
        Write-Log "  Device ID (hex):         $($g.DeviceIdHex)"
        Write-Log "  Subsystem ID:            $($g.SubsystemId)"
        Write-Log "  PCI Location:            $($g.PciLocation)"
        $hwExtra = [ordered]@{
            'Chip Type:      ' = $g.ChipType
            'DAC Type:       ' = $g.DacType
            'Adapter String: ' = $g.AdapterString
            'VBIOS:          ' = $g.VBios
        }
        $hwReported = @($hwExtra.GetEnumerator() | Where-Object { $_.Value -ne 'N/A' })
        if ($hwReported.Count -gt 0) {
            foreach ($item in $hwReported) { Write-Log "  $($item.Key)         $($item.Value)" }
        } else {
            Write-Log "  Chip/DAC/VBIOS:          (not reported by driver)"
        }

        Write-Log "`n Memory & Display:"
        Write-Log "  Adapter RAM (dedicated): $($g.AdapterRAM)"
        Write-Log "  Shared System Memory:    $($g.SharedMemory)"
        Write-Log "  Current Resolution:      $($g.CurrentResolution)"
        Write-Log "  Refresh Rate:            $($g.RefreshRate)"
        Write-Log "  Max Refresh Rate:        $($g.MaxRefreshRate)"
        Write-Log "  Color Depth:             $($g.BitsPerPixel)"

        Write-Log "`n Driver Details:"
        Write-Log "  Driver Version:          $($g.DriverVersion)"
        Write-Log "  Driver Date:             $($g.DriverDate)"
        Write-Log "  Driver Install Date:     $($g.DriverInstallDate)"
        Write-Log "  Driver Provider:         $($g.DriverProvider)"
        Write-Log "  Signature Status:        $($g.DriverSigned)"
        Write-Log "  Signer:                  $($g.DriverSigner)"
        Write-Log "  INF Name:                $($g.InfName)"
        Write-Log "  Max D3D12 Feature Level: $($g.MaxFeatureLevel)"
        Write-Log "  OpenGL Driver:           $(if ($g.OpenGLDriver -eq 'N/A') { '(not reported by driver)' } else { $g.OpenGLDriver })"
        Write-Log "  Device ID:               $($g.Index)"

        if ($g.Name -match 'Microsoft Basic Display') {
            Write-Log "`n  Warning: generic Microsoft driver in use; the vendor GPU driver is not installed."
        }
        if ($null -ne $g.ErrorCodeRaw -and [int]$g.ErrorCodeRaw -ne 0) {
            Write-Log "`n  Warning: device reports problem - $($g.ErrorCode)"
        }
        if ($g.DriverSigned -eq 'Not signed') {
            Write-Log "`n  Warning: the display driver is not digitally signed."
        }

        Write-Log ""
        $i++
    }

    Write-Log "System Graphics Details:"
    Write-Log "  DirectX Version:               $($sysInfo.DirectXVersion)"
    Write-Log "  DirectX Registry Version:      $($sysInfo.DirectXRegistry) (legacy value, does not reflect DX12)"
    Write-Log "  HW-Accelerated GPU Scheduling: $($sysInfo.HwScheduling)"
    Write-Log "  VRR in Windowed Games:         $($sysInfo.VrrWindowedGames)"
    Write-Log "  Hybrid Graphics:               $($sysInfo.HybridGraphics)"

    Write-Log "`n Graphics APIs:"
    $vk = $sysInfo.Vulkan
    Write-Log "  Vulkan Loader:           $(if ($vk.LoaderPresent) { "Present (v$($vk.LoaderVersion))" } else { 'Not found' })"
    Write-Log "  Vulkan Driver Manifests: $(if ($vk.Drivers.Count -gt 0) { $vk.Drivers -join '; ' } else { 'N/A' })"
    $cp = $sysInfo.Compute
    Write-Log "  CUDA:                    $(if ($cp.CudaAvailable) { "Available (nvcuda.dll $($cp.CudaDriverDll))" } else { 'Not available' })"
    Write-Log "  OpenCL:                  $(if ($cp.OpenCLAvailable) { "Available (loader $($cp.OpenCLLoader))" } else { 'Not available' })"
    Write-Log "  OpenCL Vendors:          $(if ($cp.OpenCLVendors.Count -gt 0) { $cp.OpenCLVendors -join '; ' } else { 'N/A' })"

    Write-Log "`n Connected Monitors ($($sysInfo.Monitors.Count)):"
    if ($sysInfo.Monitors.Count -gt 0) {
        $m = 1
        foreach ($mon in $sysInfo.Monitors) {
            Write-Log "  Monitor #$m - $($mon.Name)"
            Write-Log "    Manufacturer:          $($mon.Manufacturer)"
            Write-Log "    Product Code:          $($mon.ProductCode)"
            Write-Log "    Serial:                $($mon.Serial)"
            Write-Log "    Year of Manufacture:   $($mon.YearOfManufacture)"
            Write-Log "    Size:                  $($mon.Size)"
            $m++
        }
    } else {
        Write-Log "  No monitor information available."
    }

    Write-Log "`n Display Driver Events (last 30 days):"
    Write-Log "  Driver Timeout Resets (Event 4101): $($sysInfo.Events.TdrCount30d)"
    if ($sysInfo.Events.Recent.Count -gt 0) {
        foreach ($e in $sysInfo.Events.Recent) {
            Write-Log "  [$($e.Time)] $($e.Provider) (ID $($e.EventId), $($e.Level)): $($e.Message)"
        }
    } else {
        Write-Log "  No recent display driver errors or warnings found."
    }
} else {
    Write-Log "No GPU information found on this system."
}
