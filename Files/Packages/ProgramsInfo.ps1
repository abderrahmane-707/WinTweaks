param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# --- 1. Startup Programs Section ---
try {
    Write-Log "Startup Programs:"

    # 1. Fetch via WMI/CIM and clean up long SID paths
    $startupFromWmi = @(
        try {
            Get-CimInstance Win32_StartupCommand -ErrorAction Stop |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and -not [string]::IsNullOrWhiteSpace($_.Command) } |
                ForEach-Object {
                    # Shorten long HKU\S-1-5-... paths to HKCU for clean table output
                    $cleanLocation = $_.Location -replace '^HKU\\S-1-5-[0-9-]+', 'HKCU'
                    [PSCustomObject]@{
                        Name     = $_.Name
                        Command  = $_.Command
                        Location = $cleanLocation
                    }
                }
        } catch {
            Write-Log "Warning: Unable to fetch startup items via WMI/CIM: $_"
            @()
        }
    )

    # 2. Fetch directly from Registry
    $startupRegPaths = @(
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' },
        @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
        @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' }
    )

    $startupFromRegistry = foreach ($entry in $startupRegPaths) {
        if (Test-Path $entry.Path) {
            $item = Get-ItemProperty -Path $entry.Path -ErrorAction SilentlyContinue
            if ($item) {
                $item.PSObject.Properties |
                    Where-Object {
                        $_.Name -notmatch '^PS' -and 
                        $_.Name -ne '(default)' -and 
                        -not [string]::IsNullOrWhiteSpace($_.Value)
                    } |
                    ForEach-Object {
                        [PSCustomObject]@{
                            Name     = $_.Name
                            Command  = $_.Value
                            Location = $entry.Path
                        }
                    }
            }
        }
    }

    # Merge and deduplicate smartly based on Command
    $allStartup = @($startupFromWmi) + @($startupFromRegistry)
    $startup = @($allStartup | Group-Object Command | ForEach-Object { $_.Group[0] } | Sort-Object Name)

    if ($startup.Count -gt 0) {
        # Format table with concise columns
        $startupTable = $startup | Format-Table Name, Command, Location -AutoSize | Out-String
        Write-Log $startupTable
        Write-Log "Total startup programs: $($startup.Count)"
    } else {
        Write-Log "No startup programs found"
    }
}
catch {
    Write-Log "Error while enumerating startup programs: $_"
}

# --- 2. Installed Programs Section ---
try {
    Write-Log "`nInstalled Programs:"
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $programs = foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue
        }
    }

    $installed = @(
        $programs |
            Where-Object {
                $_.DisplayName -and
                $_.DisplayName -ne '' -and
                $_.SystemComponent -ne 1 -and
                $_.WindowsInstaller -ne 1 -and
                $_.ReleaseType -ne 'Security Update' -and
                $_.ParentKeyName -notmatch 'update'
            } |
            Select-Object @{ Name = 'Program'; Expression = { $_.DisplayName } },
            @{ Name = 'Version'; Expression = { $_.DisplayVersion } },
            @{ Name = 'Publisher'; Expression = { if ($_.Publisher) { $_.Publisher } else { "N/A" } } },
            @{ Name = 'InstallDate'; Expression = {
                    if ($_.InstallDate -match '^\d{8}$') {
                        $parsedDate = [datetime]::MinValue
                        if ([datetime]::TryParseExact($_.InstallDate, 'yyyyMMdd', $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                            $parsedDate.ToString('dd/MM/yyyy')
                        } else {
                            $_.InstallDate
                        }
                    } else {
                        if ($_.InstallDate) { $_.InstallDate } else { "N/A" }
                    }
                }
            },
            @{ Name = 'Size'; Expression = {
                    if ($_.EstimatedSize) { "$([math]::Round($_.EstimatedSize / 1024, 2)) MB" } else { "N/A" }
                }
            } |
            Sort-Object Program, Version -Unique
    )

    if ($installed.Count -gt 0) {
        $installedTable = $installed | Format-Table -AutoSize | Out-String
        Write-Log $installedTable

        Write-Log "Total installed programs: $($installed.Count)"
    } else {
        Write-Log "No installed programs found in registry"
    }
}
catch {
    Write-Log "Error while enumerating installed programs: $_"
}
