function Get-GPUInfo {
    try {
        # Query WMI for video controller information (primary GPU details)
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    } catch {
        Write-Output "Unable to query Win32_VideoController: $($_.Exception.Message)"
        return @()  # Return empty array if query fails
    }

    try {
        # Query WMI for signed display drivers to get driver-specific information
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
                   Where-Object { ($_.DeviceClass -eq 'DISPLAY') -or 
                                 ($_.DeviceName -like '*Display*') -or 
                                 ($_.DeviceName -like '*Video*') }
    } catch {
        Write-Output "Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        $drivers = @()  # Initialize empty array if driver query fails
    }

    $result = @()  # Initialize empty array to store GPU information objects
    
    # Process each GPU found in the system
    foreach ($g in $gpus) {
        $matchingDriver = $null
        
        # Attempt to find a matching driver for this GPU using device IDs or names
        if ($g.PNPDeviceID -and $drivers) {
            $matchingDriver = $drivers | Where-Object { 
                $_.DeviceID -like "*$($g.PNPDeviceID)*" -or
                $_.DeviceID -eq $g.PNPDeviceID
            } | Select-Object -First 1  # Take the first matching driver
            
            # Fallback: Try to match by device name if device ID didn't match
            if (-not $matchingDriver) {
                $matchingDriver = $drivers | Where-Object { 
                    $_.DeviceName -like "*$($g.Name)*" -or
                    $_.DeviceName -eq $g.Name
                } | Select-Object -First 1
            }
        }

        # Process driver date information (convert from WMI date format if possible)
        $driverDate = $null
        if ($matchingDriver -and $matchingDriver.DriverDate) {
            try {
                # Convert WMI datetime format to standard DateTime object
                $driverDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($matchingDriver.DriverDate)
            } catch {
                $driverDate = $matchingDriver.DriverDate  # Use raw value if conversion fails
            }
        } elseif ($g.DriverDate) {
            try {
                $driverDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($g.DriverDate)
            } catch {
                $driverDate = $g.DriverDate
            }
        }

        # Get INF file name (driver installation file) if available
        $infName = if ($matchingDriver) { 
            $matchingDriver.InfName 
        } else { 
            "N/A" 
        }

        # Convert adapter RAM from bytes to megabytes for readability
        $adapterRAMMB = $null
        if ($g.AdapterRAM -ne $null) {
            $adapterRAMMB = [math]::Round($g.AdapterRAM / 1MB, 2)
        }

        # Format current resolution and refresh rate information
        $currentRes = if ($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution) {
            "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz"
        } else {
            $g.VideoModeDescription  # Fallback to video mode description
        }

        # Create a custom object with all GPU properties for this GPU
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
        $result += $obj  # Add this GPU object to the results array
    }

    return $result  # Return array of GPU information objects
}

# Function to retrieve display driver information specifically
function Get-GPUDrivers {
    try {
        # Query WMI for signed display drivers (filtering for display/video devices)
        $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop |
                   Where-Object { ($_.DeviceClass -eq 'DISPLAY') -or 
                                 ($_.DeviceName -like '*Display*') -or 
                                 ($_.DeviceName -like '*Video*') }
    } catch {
        Write-Output "WARNING: Unable to query Win32_PnPSignedDriver: $($_.Exception.Message)"
        return @()  # Return empty array on error
    }
    
    # Return selected driver properties
    $drivers | Select-Object DeviceName, Manufacturer, DriverVersion, DriverProviderName, DeviceID
}

# Function to retrieve DirectX version from Windows Registry
function Get-DirectXVersion {
    try {
        # Read DirectX version from Windows Registry (HKLM = HKEY_LOCAL_MACHINE)
        $dx = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction Stop
        if ($dx -and $dx.Version) {
            return $dx.Version  # Return DirectX version if found
        } else {
            return $null  # Return null if version key exists but is empty
        }
    } catch {
        return $null  # Return null if registry key doesn't exist or access is denied
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