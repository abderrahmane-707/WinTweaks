[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param ()

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

# Convert array to a single regex pattern, anchored to the start of the name
# to avoid unintended partial matches (e.g. "News" matching inside unrelated package names)
$RegexPattern = "^(" + (($AppxPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|') + ")"

# Shared removal logic for both provisioned and installed packages.
# Uses the caller's $PSCmdlet so -WhatIf/-Confirm from the main script flow through
# to each individual removal (ShouldProcess handles per-item [Y/N/A] prompting natively).
function Remove-MatchedPackages {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory=$true)] $Packages,
        [Parameter(Mandatory=$true)] [scriptblock]$RemoveAction,
        [Parameter(Mandatory=$true)] [string]$NameProperty
    )

    $removed = 0
    $failed = 0

    foreach ($pkg in $Packages) {
        $displayName = $pkg.$NameProperty

        if ($PSCmdlet.ShouldProcess($displayName, "Remove Appx package")) {
            try {
                & $RemoveAction $pkg
                Write-Host "Successfully removed: $displayName"
                $removed++
            }
            catch {
                Write-Warning "Failed to remove $($displayName): $_"
                $failed++
            }
        }
    }

    return [PSCustomObject]@{ Removed = $removed; Failed = $failed }
}

# --- Gather packages (with error handling around the retrieval calls) ---

Write-Host "`nChecking for Provisioned Packages to remove"
try {
    $provisionedPackages = @(
        Get-AppxProvisionedPackage -Online -ErrorAction Stop |
            Where-Object { $_.DisplayName -match $RegexPattern }
    )
}
catch {
    Write-Warning "Failed to query provisioned packages: $_"
    $provisionedPackages = @()
}

Write-Host "`nChecking for installed Appx Packages"
try {
    $packagesToRemove = @(
        Get-AppxPackage -AllUsers -ErrorAction Stop |
            Where-Object { $_.Name -match $RegexPattern }
    )
}
catch {
    Write-Warning "Failed to query installed packages: $_"
    $packagesToRemove = @()
}

if ($packagesToRemove.Count -eq 0 -and $provisionedPackages.Count -eq 0) {
    Write-Host "No matching packages found (or none could be queried). Nothing to do"
    exit 0
}

# Build a single unified list of every package (provisioned + installed) for review,
# de-duplicated by name so packages present in both categories are only shown once.
$allNames = @()
$allNames += $provisionedPackages | ForEach-Object { $_.DisplayName }
$allNames += $packagesToRemove | ForEach-Object { $_.Name }
$uniqueNames = $allNames | Sort-Object -Unique

Write-Host "`nThe following $($uniqueNames.Count) package(s) will be removed:"
$uniqueNames | ForEach-Object { Write-Host " - $_" }

$totalRemoved = 0
$totalFailed = 0

if ($provisionedPackages.Count -gt 0) {
    Write-Host "`nRemoving provisioned packages"
    $result = Remove-MatchedPackages -Packages $provisionedPackages -NameProperty "DisplayName" -RemoveAction {
        param($pkg)
        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
    }
    $totalRemoved += $result.Removed
    $totalFailed += $result.Failed
}

if ($packagesToRemove.Count -gt 0) {
    Write-Host "`nRemoving installed packages"
    $result = Remove-MatchedPackages -Packages $packagesToRemove -NameProperty "Name" -RemoveAction {
        param($pkg)
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
    }
    $totalRemoved += $result.Removed
    $totalFailed += $result.Failed
}

# Unified summary covering both provisioned and installed packages
Write-Host "`nRemoved: $totalRemoved"
Write-Host "Failed: $totalFailed"
