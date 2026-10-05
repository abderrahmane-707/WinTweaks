[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param ()

# Exact package names (case-insensitive exact match)
$ExactNames = @(
    'Microsoft.BingFinance', 'Microsoft.BingNews', 'Microsoft.BingSports',
    'Microsoft.BingTravel', 'Microsoft.BingWeather', 'Microsoft.GamingApp',
    'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.Messaging',
    'Microsoft.Microsoft3DViewer', 'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.NetworkSpeedTest',
    'Microsoft.News', 'Microsoft.Office.OneNote', 'Microsoft.Print3D',
    'Microsoft.SkypeApp', 'Microsoft.WindowsAlarms', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps', 'Microsoft.WindowsSoundRecorder', 'Microsoft.XboxApp',
    'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo',
    'microsoft.windowscommunicationsapps'   # Mail and Calendar - remove from the list if needed
)
$ExactSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$ExactNames, [System.StringComparer]::OrdinalIgnoreCase)

# Third-party packages: the publisher prefix varies (e.g. king.com.CandyCrushSaga,
# SpotifyAB.SpotifyMusic), so match the app name after the first dot
$VendorRegex = [regex]::new(
    '^[^.]+\.(AdobePhotoshopExpress|CandyCrush|Facebook|LinkedIn|Netflix|Spotify|Twitter)',
    'IgnoreCase, Compiled')

function Test-TargetName {
    param ([string]$Name)
    return $ExactSet.Contains($Name) -or $VendorRegex.IsMatch($Name)
}

# Gather packages (one query per package type)
Write-Host "`nChecking for installed Appx packages"
try {
    # -AllUsers returns one entry per user, so de-duplicate by full package name
    $installed = @(
        Get-AppxPackage -AllUsers -ErrorAction Stop |
            Where-Object { Test-TargetName $_.Name } |
            Sort-Object -Property PackageFullName -Unique
    )
}
catch {
    Write-Warning "Failed to query installed packages: $($_.Exception.Message)"
    $installed = @()
}

Write-Host "Checking for provisioned packages"
try {
    $provisioned = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { Test-TargetName $_.DisplayName } |
            Sort-Object -Property PackageName -Unique
    )
}
catch {
    Write-Warning "Failed to query provisioned packages: $($_.Exception.Message)"
    $provisioned = @()
}

if ($installed.Count -eq 0 -and $provisioned.Count -eq 0) {
    Write-Host "No matching packages found (or none could be queried). Nothing to do"
    exit 0
}

# Unified, de-duplicated list for review
$uniqueNames = @(
    @($installed | ForEach-Object { $_.Name }) +
    @($provisioned | ForEach-Object { $_.DisplayName })
) | Sort-Object -Unique

Write-Host "The following $($uniqueNames.Count) package(s) will be removed:"
$uniqueNames | ForEach-Object { Write-Host "  - $_" }

# Single confirmation for the whole batch (-WhatIf and -Confirm work here)
$total = $installed.Count + $provisioned.Count
if (-not $PSCmdlet.ShouldProcess("$total Appx package(s)", 'Remove')) {
    Write-Host "Operation cancelled (WhatIf or declined)."
    exit 0
}

$removed = 0
$failed  = 0

# Remove installed packages first, then provisioned ones (no need to re-query)
if ($installed.Count -gt 0) {
    Write-Host "Removing installed packages"
    foreach ($pkg in $installed) {
        try {
            $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
            Write-Host "  Successfully removed: $($pkg.Name)"
            $removed++
        }
        catch {
            Write-Warning "Failed to remove $($pkg.Name): $($_.Exception.Message)"
            $failed++
        }
    }
}

if ($provisioned.Count -gt 0) {
    Write-Host "Removing provisioned packages"
    foreach ($pkg in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
            Write-Host "  Successfully removed: $($pkg.DisplayName)"
            $removed++
        }
        catch {
            Write-Warning "Failed to remove $($pkg.DisplayName): $($_.Exception.Message)"
            $failed++
        }
    }
}

Write-Host "Removed: $removed"
Write-Host "Failed: $failed"
