# List of Appx packages to remove
$AppxPackages = @(
    "*AdobePhotoshopExpress*",
    "*CandyCrush*",
    "*Facebook*",
    "*LinkedIn*",
    "*Netflix*",
    "*Spotify*",
    "*Twitter*",
    "*Xbox*",
    "Microsoft.BingFinance",
    "Microsoft.BingNews",
    "Microsoft.BingSports",
    "Microsoft.BingTravel",
    "Microsoft.BingWeather",
    "Microsoft.GamingApp",
    "Microsoft.GetHelp",
    "Microsoft.GetStarted",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.NetworkSpeedTest",
    "Microsoft.News",
    "Microsoft.Office.OneNote",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.SkypeApp",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameCallableUI",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentities",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)

# Start removing Appx packages
Write-Host "`nStarting remove Microsoft store apps"

# Loop through each package pattern
foreach ($pattern in $AppxPackages) {
    try {
        # Find packages matching the pattern
        $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $pattern }
        
        # Remove each matching package
        foreach ($package in $packages) {
            Write-Host " - Removing: $($package.Name)"
            
            # Remove for current user
            Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
            
            # Remove for all users if running as admin
            if ($IsAdmin) {
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
           
        }
    }
    catch {
        Write-Host "Error removing pattern '$pattern': $_"
    }
}

# Checking for Microsoft Teams
$TeamsPath = "$Env:LocalAppData\Microsoft\Teams\Update.exe"

if (Test-Path $TeamsPath) {
    Write-Host "Uninstalling Teams"
    try {
        # Start Teams uninstaller
        Start-Process $TeamsPath -ArgumentList "-uninstall" -Wait -ErrorAction Stop
    }
    catch {
        Write-Host "Error uninstalling Teams: $_"
    }
    
    # Wait for uninstall to complete
    Start-Sleep -Seconds 5
    
    Write-Host "Deleting Teams directory"
    try {
        # Remove Teams directories for all users
        Remove-Item "C:\Users\*\AppData\Local\Microsoft\Teams" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $TeamsPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "Error deleting Teams directory: $_"
    }
}

# Clean up provisioned apps
Write-Host "Cleaning up provisioned apps"

# Loop through each pattern defined in the $AppxPackages list
foreach ($pattern in $AppxPackages) {
    try {
        # Find provisioned packages matching the display name or package name pattern
        $provisioned = Get-AppxProvisionedPackage -Online | 
            Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern }
        
        # Remove each identified provisioned package
        foreach ($app in $provisioned) {
            Write-Host "Removing provisioned: $($app.DisplayName)"
            
            # Executing the removal command
            Remove-AppxProvisionedPackage -Online -PackageName $app.PackageName -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Host "Error removing provisioned package '$pattern': $_"
    }
}