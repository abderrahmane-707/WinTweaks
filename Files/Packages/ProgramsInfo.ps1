param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Enumerate startup programs and installed applications
try {
    Write-Log "Startup Programs:"
    
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction Stop | 
        Select-Object Name, Command, User 
    
    if ($startup.Count -gt 0) {
        $startupTable = $startup | Format-Table -AutoSize | Out-String
        Write-Log $startupTable
    } else {
        Write-Log "No startup programs found"
    }
    
    Write-Log "Installed Programs:"
    
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $programs = foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue
        }
    }

    $installed = $programs | 
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
        } | Sort-Object Program -Unique

    if ($installed.Count -gt 0) {
        $installedTable = $installed | Format-Table | Out-String
        Write-Log $installedTable
        
        Write-Log "`nTotal installed programs: $($installed.Count)"
    } else {
        Write-Log "No installed programs found in registry"
    }

} catch {
    Write-Log "Error: $_"
}