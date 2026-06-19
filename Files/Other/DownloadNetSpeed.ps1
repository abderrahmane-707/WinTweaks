# Temp paths
$TempZip   = Join-Path $env:TEMP "speedtest_cli.zip"
$ExtractDir = Join-Path $env:TEMP "speedtest_cli"
$ExePath   = Join-Path $ExtractDir "speedtest.exe"

# Download source
$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"

# Ensure extract directory exists
if (-not (Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}

# Download + extract if missing
if (-not (Test-Path $ExePath)) {
    Write-Host "Downloading Speedtest CLI"

    try {
        # Optimize download
        $ProgressPreference = 'Continue'
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
Write-Host "Running Internet Speed Test"

try {
    & $ExePath --accept-license --accept-gdpr
}
catch {
    Write-Error "Execution failed: $($_.Exception.Message)"
}