# Folder path to archive
param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

# Validate source folder
if (-not (Test-Path $FolderPath)) {
    Write-Error "Base path does not exist: $FolderPath"
    exit 1
}

# Output archive path
$ZipPath = "$FolderPath.zip"

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

    # Remove source folder
    Remove-Item $FolderPath -Recurse -Force

    # Display summary
    Write-Host ""
    Write-Host "Size Before compress: $FormattedFolderSize"
    Write-Host "Size After compress: $FormattedZipSize"
    Write-Host "Backup saved in: $ZipPath"
}