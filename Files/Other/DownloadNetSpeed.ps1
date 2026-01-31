$TempZip = Join-Path $env:TEMP "speedtest_cli.zip"
$ExtractDir = Join-Path $env:TEMP "speedtest_cli"
$ExePath = Join-Path $ExtractDir "speedtest.exe"

$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"

if (-not (Test-Path $ExtractDir)) {
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
}

if (Test-Path $ExePath) {
} else {
    Write-Host "Downloading speedtest CLI"
    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
       
        (New-Object System.Net.WebClient).DownloadFile($DownloadUrl, $TempZip)
		
    } catch {
        Write-Host "Download error: $($_.Exception.Message)"
        Write-Host "You can download it manually from: $DownloadUrl"
        exit 1
    }

    try {
        Expand-Archive -Path $TempZip -DestinationPath $ExtractDir -Force
    } catch {
        Write-Host "Extraction error: $($_.Exception.Message)"
        exit 1
    }
    
    if (Test-Path $TempZip) {
        Remove-Item -Path $TempZip -Force
    }
}

Write-Host "Running Internet Speed Test"
try {
    & $ExePath --accept-license --accept-gdpr
} catch {
    Write-Host "Failed to run Speedtest: $($_.Exception.Message)"
}