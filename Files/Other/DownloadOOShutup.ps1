$OOSU_DIR = "$env:TEMP\OOSU10"
$OOSU_EXE = "$OOSU_DIR\OOSU10.exe"

if (!(Test-Path $OOSU_DIR)) {
    mkdir $OOSU_DIR -Force | Out-Null
}

if (!(Test-Path $OOSU_EXE)) {
    Write-Host "Downloading OO ShutUp10"   
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    try {
        Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -OutFile $OOSU_EXE
    } catch {
        Write-Host "Failed to download OO ShutUp10"
        exit 1
    }
}

Write-Host "Running OO ShutUp10"
Start-Process $OOSU_EXE