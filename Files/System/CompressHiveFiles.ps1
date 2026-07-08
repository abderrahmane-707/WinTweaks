param (
    [Parameter(Position = 0)]
    [string]$FolderPath,
    
    [Parameter(Position = 1)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Output archive path
$ZipPath = "$FolderPath.zip"

# Check for the presence of a compressed file and prompt for deletion
if (Test-Path $ZipPath) {
    $ZipFileName = Split-Path $ZipPath -Leaf
    
    # Request confirmation for deletion
    choice /C YN /N /M "`n$ZipFileName already exists. Do you want to replace the existing archive? (Y/N): "
    
    if ($LASTEXITCODE -eq 2) {
        Write-Log "Keeping the existing archive. Compression cancelled"
        exit 0
    }
}

# Calculate folder size
function Get-FolderSize {
    param([string]$Path)
    $items = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue
    ($items | Measure-Object Length -Sum).Sum
}

# Convert bytes to readable format
function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N2} KB" -f ($Bytes / 1KB) }
    else { "$Bytes Bytes" }
}

# Get source size
$FolderSize = Get-FolderSize -Path $FolderPath
$FormattedFolderSize = Format-FileSize -Bytes $FolderSize

# Create ZIP archive
Write-Log "`nCompressing hive files"
try {
    Compress-Archive `
        -Path "$FolderPath\*" `
        -DestinationPath $ZipPath `
        -CompressionLevel Optimal `
        -Force `
        -ErrorAction Stop
}
catch {
    Write-Log "Compression failed - $_"
    exit 1
}

# Verify archive creation
if (Test-Path $ZipPath) {

    # Get archive size
    $ZipSize = (Get-Item $ZipPath).Length
    $FormattedZipSize = Format-FileSize -Bytes $ZipSize

    # Remove temporary source folder
    Write-Log "Deleting $FolderPath"
    Remove-Item $FolderPath -Recurse -Force

    # Display summary
    Write-Log "`nSize Before compress: $FormattedFolderSize"
    Write-Log "Size After compress:  $FormattedZipSize"
    Write-Log "`nBackup saved in: $ZipPath"
}
else {
    Write-Log "Archive was not created"
    exit 1
}