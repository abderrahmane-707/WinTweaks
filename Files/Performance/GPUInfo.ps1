param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Query GPU and driver information via CIM
function Get-GPUInfo {
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    } catch {
        Write-Warning "Unable to query Win32_VideoController: $($_.Exception.Message)"
        return @()
    }

    try {
        $wqlQuery = "SELECT * FROM Win32_PnPSignedDriver WHERE DeviceClass = 'DISPLAY' OR DeviceName LIKE '%Display%' OR DeviceName LIKE '%Video%'"
        $drivers = Get-CimInstance -Query $wqlQuery -ErrorAction Stop
    } catch {
        Write-Warning "Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        $drivers = @()
    }

    $result = foreach ($g in $gpus) {
        $matchingDriver = $null

        # Match driver by PNPDeviceID or device name
        if ($g.PNPDeviceID -and $drivers) {
            $matchingDriver = $drivers | Where-Object {
                $_.DeviceID -like "*$($g.PNPDeviceID)*" -or $_.DeviceID -eq $g.PNPDeviceID
            } | Select-Object -First 1

            if (-not $matchingDriver) {
                $matchingDriver = $drivers | Where-Object {
                    $_.DeviceName -like "*$($g.Name)*" -or $_.DeviceName -eq $g.Name
                } | Select-Object -First 1
            }
        }

        # Convert driver date to readable format
        $driverDate = $null
        $rawDate = if ($matchingDriver) { $matchingDriver.DriverDate } else { $g.DriverDate }
        if ($rawDate) {
            try {
                $driverDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($rawDate)
            } catch {
                $driverDate = $rawDate
            }
        }

        $infName = if ($matchingDriver) { $matchingDriver.InfName } else { "N/A" }
        $adapterRAMMB = if ($null -ne $g.AdapterRAM) { [math]::Round($g.AdapterRAM / 1MB, 2) } else { $null }

        # Build current resolution string with refresh rate if available
        $currentRes = if ($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution) {
            "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz"
        } else {
            $g.VideoModeDescription
        }

        [PSCustomObject]@{
            'Index'                = if ($g.DeviceID) { $g.DeviceID } else { "N/A" }
            'Name'                 = if ($g.Name) { $g.Name.Trim() } else { "N/A" }
            'PNPDeviceID'          = if ($g.PNPDeviceID) { $g.PNPDeviceID } else { "N/A" }
            'VideoProcessor'       = if ($g.VideoProcessor) { $g.VideoProcessor } else { "N/A" }
            'AdapterCompatibility' = if ($g.AdapterCompatibility) { $g.AdapterCompatibility } else { "N/A" }
            'DriverVersion'        = if ($g.DriverVersion) { $g.DriverVersion } else { "N/A" }
            'DriverDate'           = if ($driverDate) { $driverDate } else { "N/A" }
            'InfName'              = if ($infName) { $infName } else { "N/A" }
            'AdapterRAM_MB'        = if ($adapterRAMMB) { "$adapterRAMMB MB" } else { "N/A" }
            'CurrentResolution'    = if ($currentRes) { $currentRes } else { "N/A" }
            'VideoModeDescription' = if ($g.VideoModeDescription) { $g.VideoModeDescription } else { "N/A" }
            'Status'               = if ($g.Status) { $g.Status } else { "N/A" }
        }
    }

    return $result
}

# Read DirectX version from registry
function Get-DirectXVersion {
    try {
        $dx = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction Stop
        if ($dx -and $dx.Version) { return $dx.Version }
    } catch {
        return "Unknown"
    }
}

# Gather and log all GPU details
$gpuInfo = Get-GPUInfo
$dxVersion = Get-DirectXVersion

if ($gpuInfo) {
    $i = 1
    foreach ($g in $gpuInfo) {
        Write-Log "GPU #$i - $($g.Name)"
        Write-Log " Basic Information:"
        Write-Log "  Name:                    $($g.Name)"
        Write-Log "  Video Processor:         $($g.VideoProcessor)"
        Write-Log "  Manufacturer:            $($g.AdapterCompatibility)"
        Write-Log "  Status:                  $($g.Status)"
        
        Write-Log "`n Memory & Display:"
        Write-Log "  Adapter RAM:             $($g.AdapterRAM_MB)"
        Write-Log "  Current Resolution:      $($g.CurrentResolution)"
        Write-Log "  Video Mode:              $($g.VideoModeDescription)"
        
        Write-Log "`n Technical Details:"
        Write-Log "  Driver Version:          $($g.DriverVersion)"
        Write-Log "  Driver Date:             $($g.DriverDate)"
        Write-Log "  INF Name:                $($g.InfName)"
        Write-Log "  Device ID:               $($g.Index)"
		Write-Log ""
        $i++
    }
    Write-Log "DirectX Version: $dxVersion"
}