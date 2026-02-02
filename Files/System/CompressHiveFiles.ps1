# Script parameter: Mandatory folder path to be compressed and backed up
param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

# Validate that the specified folder exists
if (-not (Test-Path $FolderPath)) {
    Write-Error "Base path does not exist: $FolderPath"
    exit 1
}

# Define the ZIP file path (same name as folder with .zip extension)
$ZipPath = "$FolderPath.zip"

# Function to calculate total size of a folder (including all subfolders)
function Get-FolderSize {
    param([string]$Path)
    # Recursively get all files in the folder, skip any access errors
    $items = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue
    # Sum up the lengths (sizes) of all files
    ($items | Measure-Object Length -Sum).Sum
}

# Function to format file sizes into human-readable format (GB, MB, KB)
function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N2} KB" -f ($Bytes / 1KB) }
    else { "$Bytes Bytes" }
}

# Calculate original folder size before compression
$FolderSize = Get-FolderSize -Path $FolderPath
$FormattedFolderSize = Format-FileSize -Bytes $FolderSize

# Compress the folder into a ZIP archive
# -Path "$FolderPath\*": Compress all contents of the folder (not the folder itself)
# -CompressionLevel Optimal: Best compression ratio (slower but smaller file)
# -Force: Overwrite existing ZIP file if it exists
Compress-Archive -Path "$FolderPath\*" -DestinationPath $ZipPath -CompressionLevel Optimal -Force

# Verify that the ZIP file was created successfully
if (Test-Path $ZipPath) {
    # Get the size of the created ZIP file
    $ZipSize = (Get-Item $ZipPath).Length
    $FormattedZipSize = Format-FileSize -Bytes $ZipSize
    
    # Remove the original folder after successful compression
    Remove-Item $FolderPath -Recurse -Force
    
    # Display compression results
    Write-Host ""
    Write-Host "Size Before compress: $FormattedFolderSize"
    Write-Host "Size After compress: $FormattedZipSize"
    Write-Host "Backup saved in: $ZipPath"
}