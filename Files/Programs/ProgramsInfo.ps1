# Function to display startup programs and installed applications
function Show-SystemPrograms {
    # Display startup programs section
    Write-Host "Startup Programs:"
    
    # Get startup commands from WMI (Common Information Model)
    $startup = Get-CimInstance Win32_StartupCommand | 
        Select-Object Name, Command, User, Location  # Select relevant properties
    
    if ($startup.Count -gt 0) {
        # Format the startup programs as a table and clean up whitespace
        $startupOutput = $startup | Format-Table -AutoSize | Out-String
        $startupOutput = ($startupOutput -replace '\r?\n\s*\r?\n', "`n").Trim()
        Write-Host $startupOutput
    } else {
        Write-Host "No startup programs found"
    }
    
    # Define registry paths where installed programs information is stored
    # HKLM: System-wide installations (all users)
    # HKCU: Current user installations
    # WOW6432Node: 32-bit programs on 64-bit Windows
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Collect installed programs from all registry paths
    $programs = foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue  # Retrieve properties with error suppression
        }
    }

    # Filter and format the installed programs
    $installed = $programs | 
        Where-Object { 
            # Filter criteria:
            $_.DisplayName -and                         # Must have a display name
            $_.DisplayName -ne '' -and                  # Display name cannot be empty
            $_.SystemComponent -ne 1 -and               # Exclude Windows system components
            $_.WindowsInstaller -ne 1 -and              # Exclude Windows Installer metadata
            $_.ReleaseType -ne 'Security Update' -and   # Exclude security updates
            $_.ParentKeyName -notmatch 'update'         # Exclude update entries
        } |
        Select-Object @{
            Name = 'Program'
            Expression = { $_.DisplayName }             # Display name of the program
        },
        @{
            Name = 'Version'
            Expression = { $_.DisplayVersion }          # Version number
        },
        @{
            Name = 'Publisher'
            Expression = { if ($_.Publisher) { $_.Publisher } else { "N/A" } }  # Publisher or N/A if not specified
        },
        @{
            Name = 'InstallDate'
            Expression = {
                # Parse install date if in yyyyMMdd format, otherwise use as-is or N/A
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
                # Convert estimated size from KB to MB if available
                if ($_.EstimatedSize) {
                    "$([math]::Round($_.EstimatedSize / 1024, 2)) MB"
                } else {
                    "N/A"
                }
            }
        } |
        Sort-Object Program  # Sort alphabetically by program name

    # Display the formatted list of installed programs
    if ($installed.Count -gt 0) {
        Write-Host ""
        Write-Host "Installed Programs List:"
        # Format as table with wrapping and fixed width for consistent output
        $tableOutput = $installed | Format-Table -AutoSize -Wrap | Out-String -Width 500
        $tableOutput = ($tableOutput -replace '\r?\n\s*\r?\n', "`n").Trim()  # Clean up whitespace
        Write-Host $tableOutput
        
        # Display total count of installed programs
        Write-Host ""
        Write-Host " Total installed programs: $($installed.Count)"
    } else {
        Write-Host "No installed programs found in registry"
    }
}

# Execute the function to display system programs
Show-SystemPrograms