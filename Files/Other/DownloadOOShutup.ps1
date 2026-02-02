# Define directory path for OO ShutUp10 tool in the system's temporary folder
# OO ShutUp10 is a privacy tool for Windows 10/11 that helps disable telemetry and privacy-invading features
$OOSU_DIR = "$env:TEMP\OOSU10"
# Define full path to the executable file
$OOSU_EXE = "$OOSU_DIR\OOSU10.exe"

# Check if the OO ShutUp10 directory exists, create it if it doesn't
if (!(Test-Path $OOSU_DIR)) {
    mkdir $OOSU_DIR -Force | Out-Null
}

# Check if OO ShutUp10 executable already exists locally
if (!(Test-Path $OOSU_EXE)) {
    Write-Host "Downloading OO ShutUp10"   
    
    # Suppress progress display during download (faster and cleaner)
    $ProgressPreference = 'SilentlyContinue'
    
    # Set security protocol to TLS 1.2 for secure HTTPS connection
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Attempt to download OO ShutUp10 from the official website
    try {
        # Download the executable from O&O Software's download server
        Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $OOSU_EXE
    } catch {
        # Handle download failure (network issues, blocked URL, etc.)
        Write-Host "Failed to download OO ShutUp10"
        exit 1  # Exit with error code 1 to indicate failure
    }
}

# Launch the OO ShutUp10 application
Write-Host "Running OO ShutUp10"
Start-Process $OOSU_EXE