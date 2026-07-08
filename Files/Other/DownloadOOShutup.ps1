param (
    [Parameter(Mandatory=$true)]
    [string]$TargetDir
)

# Paths
$OOSU_EXE    = Join-Path $TargetDir "OOSU10.exe"
$DownloadUrl = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"

# Download tool if missing
if (-not (Test-Path $OOSU_EXE)) {
    Write-Host "Downloading O&O ShutUp10"

    # Optimize download
    $ProgressPreference = 'SilentlyContinue'

    try {
        # Download latest release
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $OOSU_EXE -ErrorAction Stop
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        Write-Host "Manual URL: $DownloadUrl"
        exit 1
    }
}

# Launch application
Clear-Host
Write-Host "Running O&O ShutUp10"
Start-Process -FilePath $OOSU_EXE