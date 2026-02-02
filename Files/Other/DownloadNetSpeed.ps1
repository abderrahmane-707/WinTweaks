# Temporary ZIP file location for the downloaded package
$TempZip = Join-Path $env:TEMP "speedtest_cli.zip"
# Extraction directory for the Speedtest files
$ExtractDir = Join-Path $env:TEMP "speedtest_cli"
# Full path to the Speedtest executable
$ExePath = Join-Path $ExtractDir "speedtest.exe"

# Official Ookla Speedtest CLI download URL (Windows 64-bit version 1.2.0)
$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"

# Create extraction directory if it doesn't exist
if (-not (Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}

# Check if Speedtest executable already exists locally
if (Test-Path $ExePath) {
    # Speedtest already exists, skip download and extraction
} else {
    Write-Host "Downloading speedtest CLI"
    try {
        # Suppress progress display during download for cleaner output
        $ProgressPreference = 'SilentlyContinue'
        # Set security protocol to TLS 1.2 for secure HTTPS connection
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
       
        # Download the Speedtest CLI ZIP file using WebClient (legacy method)
        # Note: Invoke-WebRequest might be preferred in modern PowerShell
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $TempZip)
		
    } catch {
        # Handle download failure (network issues, blocked URL, etc.)
        Write-Host "Download error: $($_.Exception.Message)"
        Write-Host "You can download it manually from: $DownloadUrl"
        exit 1
    }

    # Extract the downloaded ZIP file
    try {
        Expand-Archive -Path $TempZip -DestinationPath $ExtractDir -Force
    } catch {
        Write-Host "Extraction error: $($_.Exception.Message)"
        exit 1
    }
    
    # Clean up: Remove the downloaded ZIP file after successful extraction
    if (Test-Path $TempZip) {
        Remove-Item -Path $TempZip -Force
    }
}

# Run the Speedtest CLI tool by Ookla's license
Write-Host "Running Internet Speed Test"
try {
    & $ExePath --accept-license --accept-gdpr
} catch {
    Write-Host "Failed to run Speedtest: $($_.Exception.Message)"
}