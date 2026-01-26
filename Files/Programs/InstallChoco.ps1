irm https://community.chocolatey.org/install.ps1 | iex
if ($env:ChocolateyInstall) {
    & "$env:ChocolateyInstall\bin\refreshenv.cmd"
}