# Write message to console and append to log file with UTF-8 encoding
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogPath -Value $Message -Encoding utf8
}