# Download Chocolatey
Invoke-RestMethod https://community.chocolatey.org/install.ps1 | Invoke-Expression

# Update environmental variables for the current session
if ($env:ChocolateyInstall) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
    Update-SessionEnvironment
}
