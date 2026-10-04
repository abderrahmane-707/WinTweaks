param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

$script:HadError = $false

# One failing query must not kill the whole report
function Get-CimSafe([string]$Class) {
    try {
        Get-CimInstance -ClassName $Class -ErrorAction Stop
    }
    catch {
        $script:HadError = $true
        Write-Log "  [!] $Class query failed: $($_.Exception.Message)"
        $null
    }
}

# InvariantCulture: avoids Hijri calendar / localized digits on Arabic systems
function Format-Date($Date) {
    if ($Date) { $Date.ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture) } else { 'n/a' }
}

function Write-Field([string]$Label, $Value) {
    if ($null -eq $Value -or "$Value" -eq '') { $Value = 'n/a' }
    Write-Log ('  {0,-26} {1}' -f ($Label + ':'), $Value)
}

Write-Log 'System Information:'

$os    = Get-CimSafe Win32_OperatingSystem
$cs    = Get-CimSafe Win32_ComputerSystem
$procs = @(Get-CimSafe Win32_Processor | Where-Object { $_ })
$bios  = Get-CimSafe Win32_BIOS
$tz    = Get-CimSafe Win32_TimeZone

# Build revision (UBR) and feature version are only in the registry
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$osVersion = if ($cv -and $null -ne $cv.UBR) { "$($os.Version).$($cv.UBR)" } else { $os.Version }
if ($cv.DisplayVersion) { $osVersion += " ($($cv.DisplayVersion))" }

$uptime = if ($os.LastBootUpTime) { (Get-Date) - $os.LastBootUpTime } else { $null }
$uptimeText = if ($uptime) { '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes } else { 'n/a' }

$domain = if ($cs.PartOfDomain) { "Domain: $($cs.Domain)" } else { "Workgroup: $($cs.Workgroup)" }

# Memory section intentionally omitted
Write-Field 'Host Name'             $cs.Name
Write-Field 'Domain / Workgroup'    $domain
Write-Field 'OS Name'               $os.Caption
Write-Field 'OS Version'            $osVersion
Write-Field 'OS Architecture'       $os.OSArchitecture
Write-Field 'OS Manufacturer'       $os.Manufacturer
Write-Field 'Registered Owner'      $os.RegisteredUser
Write-Field 'Product ID'            $os.SerialNumber
Write-Field 'Original Install Date' (Format-Date $os.InstallDate)
Write-Field 'System Boot Time'      (Format-Date $os.LastBootUpTime)
Write-Field 'Uptime'                $uptimeText
Write-Field 'System Manufacturer'   $cs.Manufacturer
Write-Field 'System Model'          $cs.Model
Write-Field 'System Type'           $cs.SystemType

for ($i = 0; $i -lt $procs.Count; $i++) {
    $p = $procs[$i]
    Write-Field "Processor $($i + 1)" ('{0} ({1} cores / {2} threads)' -f "$($p.Name)".Trim(), $p.NumberOfCores, $p.NumberOfLogicalProcessors)
}

Write-Field 'BIOS Version'          $bios.SMBIOSBIOSVersion
Write-Field 'BIOS Date'             (Format-Date $bios.ReleaseDate)
Write-Field 'System Directory'      $os.SystemDirectory
Write-Field 'System Locale'         (Get-WinSystemLocale).Name
Write-Field 'UI Languages'          ($os.MUILanguages -join ', ')
Write-Field 'Time Zone'             $tz.Description

if ($script:HadError) { exit 1 }
