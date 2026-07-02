# Folder path to archive
param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

# Output archive path
$ZipPath = "$FolderPath.zip"

Write-Host ""

# Check for the presence of a compressed file and delete it automatically
if (Test-Path $ZipPath) {
    Write-Host "Deleting existing file"
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
Write-Host "Compressing hive files"
Compress-Archive `
    -Path "$FolderPath\*" `
    -DestinationPath $ZipPath `
    -CompressionLevel Optimal `
    -Force

# Verify archive creation
if (Test-Path $ZipPath) {

    # Get archive size
    $ZipSize = (Get-Item $ZipPath).Length
    $FormattedZipSize = Format-FileSize -Bytes $ZipSize

    # Remove temporary source folder
    Write-Host "Deleting $FolderPath"
    Remove-Item $FolderPath -Recurse -Force

    # Display summary
    Write-Host "`nSize Before compress: $FormattedFolderSize"
    Write-Host "Size After compress:  $FormattedZipSize"
    Write-Host "Backup saved in:      $ZipPath"
}