# Temp paths
$TempZip   = Join-Path $env:TEMP "speedtest_cli.zip"
$ExtractDir = Join-Path $env:TEMP "speedtest_cli"
$ExePath   = Join-Path $ExtractDir "speedtest.exe"

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
    $ArchName    = "Windows on ARM (ARM64 - via x64 Emulation)"
} 
else {
    $DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win32.zip"
    $ArchName    = "32-bit"
}

# Ensure extract directory exists
if (-not (Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}

# Download + extract if missing
if (-not (Test-Path $ExePath)) {
    Write-Host "Downloading Speedtest CLI: $ArchName"

    try {
        # Optimize download
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -ErrorAction Stop
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
        Write-Host "Manual URL: $DownloadUrl"
        exit 1
    }

    try {
        # Extract package
        Write-Host "Extracting Speedtest CLI"
        Expand-Archive -Path $TempZip -DestinationPath $ExtractDir -Force
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
cls
Write-Host "Running Internet Speed Test"

try {
    & $ExePath --accept-license --accept-gdpr
}
catch {
    Write-Error "Execution failed: $($_.Exception.Message)"
}