function Show-SystemPrograms {
    Write-Host "Startup Programs:"
    $startup = Get-CimInstance Win32_StartupCommand | 
        Select-Object Name, Command, User, Location
    
    if ($startup.Count -gt 0) {
        $startupOutput = $startup | Format-Table -AutoSize | Out-String
        $startupOutput = ($startupOutput -replace '\r?\n\s*\r?\n', "`n").Trim()
        Write-Host $startupOutput
    } else {
        Write-Host "No startup programs found"
    }
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
        Select-Object @{
            Name = 'Program'
            Expression = { $_.DisplayName }
        },
        @{
            Name = 'Version'
            Expression = { $_.DisplayVersion }
        },
        @{
            Name = 'Publisher'
            Expression = { if ($_.Publisher) { $_.Publisher } else { "N/A" } }
        },
        @{
            Name = 'InstallDate'
            Expression = {
                if ($_.InstallDate -match '^\d{8}$') {
                    [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('dd/MM/yyyy')
                } else {
                    if ($_.InstallDate) { $_.InstallDate } else { "N/A" }
                }
            }
        },
        @{
            Name = 'Size'
            Expression = {
                if ($_.EstimatedSize) {
                    "$([math]::Round($_.EstimatedSize / 1024, 2)) MB"
                } else {
                    "N/A"
                }
            }
        } |
        Sort-Object Program

    if ($installed.Count -gt 0) {
        Write-Host ""
        Write-Host "Installed Programs List:"
        $tableOutput = $installed | Format-Table -AutoSize -Wrap | Out-String -Width 500
        $tableOutput = ($tableOutput -replace '\r?\n\s*\r?\n', "`n").Trim()
        Write-Host $tableOutput
        
        Write-Host ""
        Write-Host " Total installed programs: $($installed.Count)"
    } else {
        Write-Host "No installed programs found in registry"
    }
}
Show-SystemPrograms