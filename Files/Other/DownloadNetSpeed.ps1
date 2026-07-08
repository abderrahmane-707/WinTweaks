param (
    [Parameter(Mandatory=$true)]
    [string]$TargetDir
)

# Temp paths
$TempZip   = Join-Path $env:TEMP "speedtest_cli.zip"
$ExePath   = Join-Path $TargetDir "speedtest.exe"

# Detect architecture and set download URL
$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") { $arch = "AMD64" }

if ($arch -eq "AMD64") {
    $DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"
    $ArchName    = "64-bit"
}

# Check if the system is Windows on ARM
elseif ($arch -eq "ARM64" -or $env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
	
    # Speedtest doesn't have native Win-ARM64 binary, so we use Win64 via Windows Emulation
    $DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"
    $ArchName    = "ARM64 - via x64 Emulation"
}

else {
    $DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win32.zip"
    $ArchName    = "32-bit"
}

# Download + extract if missing
if (-not (Test-Path $ExePath)) {
    Write-Host "Downloading Speedtest CLI: $ArchName"

    try {
        # Optimize download
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -ErrorAction Stop
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        Write-Host "Manual URL: $DownloadUrl"
        exit 1
    }

    try {
        # Extract package
        Write-Host "Extracting Speedtest CLI to: $TargetDir"
        Expand-Archive -Path $TempZip -DestinationPath $TargetDir -Force
    }
    catch {
        Write-Error "Extraction failed: $($_.Exception.Message)"
        exit 1
    }

    # Cleanup archive
    if (Test-Path $TempZip) {
        Remove-Item $TempZip -Force
    }
}

# Run speed test
Clear-Host
Write-Host "Running Internet Speed Test"
& $ExePath --accept-license --accept-gdpr