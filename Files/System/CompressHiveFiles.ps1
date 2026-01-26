param (
    [Parameter(Mandatory = $true)]
    [string]$FolderPath
)

if (-not (Test-Path $FolderPath)) {
    Write-Error "Base path does not exist: $FolderPath"
    exit 1
}

$ZipPath = "$FolderPath.zip"
function Get-FolderSize {
    param([string]$Path)
    $items = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue
    ($items | Measure-Object Length -Sum).Sum
}

function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N2} KB" -f ($Bytes / 1KB) }
    else { "$Bytes Bytes" }
}

$FolderSize = Get-FolderSize -Path $FolderPath
$FormattedFolderSize = Format-FileSize -Bytes $FolderSize

Compress-Archive -Path "$FolderPath\*" -DestinationPath $ZipPath -CompressionLevel Optimal -Force

if (Test-Path $ZipPath) {
    $ZipSize = (Get-Item $ZipPath).Length
    $FormattedZipSize = Format-FileSize -Bytes $ZipSize
    Remove-Item $FolderPath -Recurse -Force
    Write-Host ""
    Write-Host "Size Before compress: $FormattedFolderSize"
    Write-Host "Size After compress: $FormattedZipSize"
    Write-Host "Backup saved in: $ZipPath"
}