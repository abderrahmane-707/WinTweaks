# Folder path to archive
param (
    [Parameter(Position = 0)]
    [string]$FolderPath,
    
    [Parameter(Position = 1)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Output archive path
$ZipPath = "$FolderPath.zip"
Write-Log ""

# Check for the presence of a compressed file and delete it automatically
if (Test-Path $ZipPath) {
    Write-Log "Deleting existing file"
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
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
Write-Log "Compressing hive files"
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
    Write-Log "Backup saved in:      $ZipPath"
}
else {
    Write-Log "Archive was not created - $ZipPath"
    exit 1
}