# 1. Download Chocolatey
irm https://community.chocolatey.org/install.ps1 | iex

# 2. Update environmental variables for the current session
if ($env:ChocolateyInstall) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
    Update-SessionEnvironment
}