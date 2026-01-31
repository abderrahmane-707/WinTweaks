function Get-GPUInfo {
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    } catch {
        Write-Output "Unable to query Win32_VideoController: $($_.Exception.Message)"
        return @()
    }

    try {
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
                   Where-Object { ($_.DeviceClass -eq 'DISPLAY') -or 
                                 ($_.DeviceName -like '*Display*') -or 
                                 ($_.DeviceName -like '*Video*') }
    } catch {
        Write-Output "Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        $drivers = @()
    }

    $result = @()
    foreach ($g in $gpus) {
        $matchingDriver = $null
        if ($g.PNPDeviceID -and $drivers) {
            $matchingDriver = $drivers | Where-Object { 
                $_.DeviceID -like "*$($g.PNPDeviceID)*" -or
                $_.DeviceID -eq $g.PNPDeviceID
            } | Select-Object -First 1
            
            if (-not $matchingDriver) {
                $matchingDriver = $drivers | Where-Object { 
                    $_.DeviceName -like "*$($g.Name)*" -or
                    $_.DeviceName -eq $g.Name
                } | Select-Object -First 1
            }
        }

        $driverDate = $null
        if ($matchingDriver -and $matchingDriver.DriverDate) {
            try {
                $driverDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($matchingDriver.DriverDate)
            } catch {
                $driverDate = $matchingDriver.DriverDate
            }
        } elseif ($g.DriverDate) {
            try {
                $driverDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($g.DriverDate)
            } catch {
                $driverDate = $g.DriverDate
            }
        }

        $infName = if ($matchingDriver) { 
            $matchingDriver.InfName 
        } else { 
            "N/A" 
        }

        $adapterRAMMB = $null
        if ($g.AdapterRAM -ne $null) {
            $adapterRAMMB = [math]::Round($g.AdapterRAM / 1MB, 2)
        }

        $currentRes = if ($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution) {
            "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz"
        } else {
            $g.VideoModeDescription
        }

        $obj = [PSCustomObject]@{
            'Index'                    = if ($g.DeviceID) { $g.DeviceID } else { "N/A" }
            'Name'                     = if ($g.Name) { $g.Name } else { "N/A" }
            'PNPDeviceID'              = if ($g.PNPDeviceID) { $g.PNPDeviceID } else { "N/A" }
            'VideoProcessor'           = if ($g.VideoProcessor) { $g.VideoProcessor } else { "N/A" }
            'AdapterCompatibility'     = if ($g.AdapterCompatibility) { $g.AdapterCompatibility } else { "N/A" }
            'DriverVersion'            = if ($g.DriverVersion) { $g.DriverVersion } else { "N/A" }
            'AdapterRAM (MB)'          = if ($adapterRAMMB) { "$adapterRAMMB MB" } else { "N/A" }
            'CurrentResolution'        = if ($currentRes) { $currentRes } else { "N/A" }
            'VideoModeDescription'     = if ($g.VideoModeDescription) { $g.VideoModeDescription } else { "N/A" }
            'Status'                   = if ($g.Status) { $g.Status } else { "N/A" }
        }
        $result += $obj
    }

    return $result
}

function Get-GPUDrivers {
    try {
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
                   Where-Object { ($_.DeviceClass -eq 'DISPLAY') -or 
                                 ($_.DeviceName -like '*Display*') -or 
                                 ($_.DeviceName -like '*Video*') }
    } catch {
        Write-Output "WARNING: Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        return @()
    }
    $drivers | Select-Object DeviceName, Manufacturer, DriverVersion, DriverProviderName, DeviceID
}

function Get-DirectXVersion {
    try {
        $dx = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction Stop
        if ($dx -and $dx.Version) {
            return $dx.Version
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

$gpuInfo = Get-GPUInfo
if ($gpuInfo -and $gpuInfo.Count -gt 0) {
    $i = 1
    foreach ($g in $gpuInfo) {
        Write-Output ""
        Write-Output "GPU #$i - $($g.Name)"
        Write-Output ""
        Write-Output " Basic Information:"
        Write-Output "  Name:   $($g.Name)"
        Write-Output "  Video Processor:  $($g.VideoProcessor)"
        Write-Output "  Manufacturer:  $($g.AdapterCompatibility)"
        Write-Output "  Status:  $($g.Status)"
        
        Write-Output ""
        Write-Output " Memory Information:"
        Write-Output "  Adapter RAM:  $($g.'AdapterRAM (MB)')"
        
        Write-Output ""
        Write-Output " Display Information:"
        Write-Output "  Current Resolution:  $($g.CurrentResolution)"
        Write-Output "  Video Mode Description:  $($g.VideoModeDescription)"
        
        Write-Output ""
        Write-Output " Technical Details:"
        Write-Output "  Driver Version:  $($g.DriverVersion)"
        Write-Output "  Device ID:  $($g.Index)"
        Write-Output "  PNP Device ID:  $($g.PNPDeviceID)"
        $i++
    }
} 