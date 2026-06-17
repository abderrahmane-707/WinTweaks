# PowerShell script to remove specified Appx packages for all users and clear provisioning
# Run this script with administrative privileges

# List of package name patterns to match (Safe patterns that won't trigger system errors)
$AppxPatterns = @(
    "AdobePhotoshopExpress", "CandyCrush", "Facebook", "LinkedIn", "Netflix", "Spotify", 
    "Twitter", "XboxApp", "BingFinance", "BingNews", "BingSports", "BingTravel", 
    "BingWeather", "GamingApp", "GetHelp", "GetStarted", "Messaging", "Microsoft3DViewer", 
    "MicrosoftOfficeHub", "MicrosoftSolitaireCollection", "NetworkSpeedTest", "News", 
    "Office.OneNote", "Print3D", "SkypeApp", "WindowsAlarms", 
    "WindowsCommunicationsApps", "FeedbackHub", "WindowsMaps", "SoundRecorder", 
    "ZuneMusic", "ZuneVideo"
)

# Convert array to a single regex pattern
$RegexPattern = ($AppxPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'

# Remove from Provisioned Packages (For future/new users)
Write-Host "`nChecking for Provisioned Packages to remove"
$provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $RegexPattern }

foreach ($pkg in $provisionedPackages) {
    try {
        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
        Write-Host "[Provisioned] Successfully removed: $($pkg.DisplayName)"
    }
    catch {
        Write-Warning "Failed to remove provisioned package $($pkg.DisplayName): $_"
    }
}

# Remove from Allt Users
Write-Host "`nChecking for installed Appx Packages"
$packagesToRemove = Get-AppxPackage -AllUsers | Where-Object { $_.Name -match $RegexPattern }

if ($packagesToRemove.Count -eq 0 -and $provisionedPackages.Count -eq 0) {
    Write-Host "No matching packages found. System is already clean"
    exit 0
}

Write-Host "Found $($packagesToRemove.Count) installed package(s) to remove:"

$removedCount = 0
$errorCount = 0

foreach ($pkg in $packagesToRemove) {
    try {
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        Write-Host "[Installed] Successfully removed: $($pkg.Name)"
        $removedCount++
    }
    catch {
        Write-Warning "Failed to remove installed package $($pkg.Name): $_"
        $errorCount++
    }
}

Write-Host "`nRemoved: $removedCount"
Write-Host "Failed: $errorCount"