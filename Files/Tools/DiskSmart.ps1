# Exit codes: 0 = OK, 1 = WARNING, 2 = CRITICAL, 3 = UNKNOWN (no SMART data)
$ErrorActionPreference = 'SilentlyContinue'
$issues = New-Object System.Collections.Generic.List[object]

function Add-Issue([string]$Level, [string]$Message) {
    $issues.Add([pscustomobject]@{ Level = $Level; Message = $Message })
}

function Format-Val($v, [string]$suffix = '') {
    if ($null -eq $v -or "$v" -eq '') { 'n/a' } else { "$v$suffix" }
}

function Get-LevelColor([string]$Level) {
    switch ($Level) {
        'CRITICAL' { 'Red' }
        'FAILING'  { 'Red' }
        'WARNING'  { 'Yellow' }
        'HOT'      { 'Yellow' }
        default    { $null }
    }
}

function Write-Colored([string]$Text, $Color) {
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

# Map SMART instances to disk numbers/models
$driveMap = @{}
foreach ($dd in (Get-CimInstance Win32_DiskDrive)) {
    if ($dd.PNPDeviceID) { $driveMap[$dd.PNPDeviceID.ToUpper()] = "Disk $($dd.Index): $($dd.Model)" }
}
function Get-DiskLabel([string]$Instance) {
    $key = ($Instance -replace '_\d+$', '').ToUpper()
    if ($driveMap.ContainsKey($key)) { "$($driveMap[$key])  [$Instance]" } else { $Instance }
}

$haveData = $false
$hasNvme  = $false

# Physical disks / reliability counters
Write-Host 'Physical disks:'
foreach ($d in (Get-PhysicalDisk | Sort-Object { [int]$_.DeviceId })) {
    $r = $d | Get-StorageReliabilityCounter
    if ($d.BusType -eq 'NVMe') { $hasNvme = $true }

    Write-Host ("`n  Disk {0}: {1}  [{2} / {3}]  {4} GB" -f $d.DeviceId, $d.FriendlyName, $d.MediaType, $d.BusType, [math]::Round($d.Size / 1GB))
    $hColor = if ($d.HealthStatus -eq 'Healthy') { $null } else { 'Red' }
    Write-Colored ("    Health: {0}    Operational: {1}" -f $d.HealthStatus, ($d.OperationalStatus -join ',')) $hColor

    if ($d.HealthStatus -ne 'Healthy') {
        $lvl = if ($d.HealthStatus -eq 'Unhealthy') { 'CRITICAL' } else { 'WARNING' }
        Add-Issue $lvl "Disk $($d.DeviceId) $($d.FriendlyName): health status is $($d.HealthStatus)"
    }

    if (-not $r) {
        Write-Host '    Reliability counters: not available for this disk (not the same as healthy)' -ForegroundColor Yellow
        continue
    }
    $haveData = $true

    $hours = if ($r.PowerOnHours) { '{0} ({1} days)' -f $r.PowerOnHours, [math]::Round($r.PowerOnHours / 24) } else { 'n/a' }
    Write-Host ("    Temperature: {0}    (max seen {1})    Wear (reported): {2}    Power-on hours: {3}" -f
        (Format-Val $r.Temperature ' C'), (Format-Val $r.TemperatureMax ' C'), (Format-Val $r.Wear '%'), $hours)
    Write-Host ("    Read errors: {0} (uncorrected {1})    Write errors: {2} (uncorrected {3})" -f
        (Format-Val $r.ReadErrorsTotal), (Format-Val $r.ReadErrorsUncorrected), (Format-Val $r.WriteErrorsTotal), (Format-Val $r.WriteErrorsUncorrected))

    if ($null -ne $r.Wear -and $r.Wear -ge 80)             { Add-Issue 'WARNING'  "Disk $($d.DeviceId): wear level is $($r.Wear)%" }
    if ($null -ne $r.Temperature -and $r.Temperature -ge 60) { Add-Issue 'WARNING'  "Disk $($d.DeviceId): temperature is $($r.Temperature) C" }
    if ($r.ReadErrorsUncorrected -gt 0 -or $r.WriteErrorsUncorrected -gt 0) {
        Add-Issue 'CRITICAL' "Disk $($d.DeviceId): uncorrected read/write errors reported"
    }
}

# SMART failure prediction
Write-Host "`nSMART failure prediction"
try {
    $fp = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop)
} catch {
    $fp = @()
    Write-Host "   Query failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
if ($fp.Count -eq 0) {
    Write-Host '   No data (NVMe/USB/RAID controllers often do not expose this)'
} else {
    $haveData = $true
    foreach ($f in $fp) {
        $label = Get-DiskLabel $f.InstanceName
        if ($f.PredictFailure) {
            Write-Host ("   {0} -> FAILURE PREDICTED" -f $label) -ForegroundColor Red
            Add-Issue 'CRITICAL' "SMART predicts failure: $label"
        } else {
            Write-Host ("   {0} -> OK (no failure predicted)" -f $label)
        }
    }
}

# Raw SMART attributes (ATA only)
Write-Host "`nRaw SMART attributes (SATA/ATA drives)"
$names = @{1='Raw Read Error Rate';3='Spin-Up Time';4='Start/Stop Count';5='Reallocated Sectors';7='Seek Error Rate';9='Power-On Hours';10='Spin Retry Count';12='Power Cycle Count';177='Wear Leveling Count';179='Used Reserved Blocks';181='Program Fail Count';182='Erase Fail Count';183='Runtime Bad Blocks';187='Reported Uncorrectable';188='Command Timeout';190='Airflow Temperature';192='Unsafe Shutdowns';193='Load Cycle Count';194='Temperature';196='Reallocation Events';197='Current Pending Sectors';198='Offline Uncorrectable';199='UDMA CRC Errors';231='SSD Life Left';233='Media Wearout Indicator';241='Total Host Writes';242='Total Host Reads'}
$warnIds   = 5, 10, 187, 196      # any raw value > 0 -> WARNING
$severeIds = 197, 198             # any raw value > 0 -> CRITICAL (sectors that cannot be read/relocated)

try {
    $smart  = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_ATAPISmartData -ErrorAction Stop)
    $thrAll = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictThresholds -ErrorAction Stop)
} catch {
    $smart = @(); $thrAll = @()
    Write-Host "   Query failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($smart.Count -eq 0) {
    Write-Host '   No ATA SMART tables found'
    if ($hasNvme) { Write-Host '   NVMe drives report health through the counters above, not through this attribute table' }
} else {
    $haveData = $true
}

foreach ($s in $smart) {
    $label = Get-DiskLabel $s.InstanceName
    $b = $s.VendorSpecific
    if (-not $b) { continue }

    $t = $thrAll | Where-Object { $_.InstanceName -eq $s.InstanceName } | Select-Object -First 1
    $thr = @{}
    if ($t -and $t.VendorSpecific) {
        for ($i = 2; $i -lt 362; $i += 12) {
            if ($t.VendorSpecific[$i] -ne 0) { $thr[[int]$t.VendorSpecific[$i]] = [int]$t.VendorSpecific[$i + 1] }
        }
    }

    Write-Host ''
    Write-Host $label -ForegroundColor Cyan
    $fmt = '{0,4}  {1,-24} {2,5} {3,5} {4,6} {5,14}  {6}'
    Write-Host ($fmt -f 'ID', 'Attribute', 'Value', 'Worst', 'Thresh', 'Raw', 'Status')

    for ($i = 2; $i -lt 362; $i += 12) {
        $id = [int]$b[$i]
        if ($id -eq 0) { continue }
        $val   = [int]$b[$i + 3]
        $worst = [int]$b[$i + 4]
        [int64]$raw = 0
        for ($k = 5; $k -ge 0; $k--) { $raw = $raw * 256 + $b[$i + 5 + $k] }

        $name = if ($names.ContainsKey($id)) { $names[$id] } else { "Attribute $id" }
        $tv   = if ($thr.ContainsKey($id)) { $thr[$id] } else { 0 }
        $status = 'OK'

        if ($id -eq 196) { $raw = $raw -band 0xFFFF }
        if ($id -eq 190 -or $id -eq 194) {
            $raw = $raw -band 0xFF
            if ($raw -ge 60) { $status = 'HOT' }
        }

        if ($tv -gt 0 -and $val -le $tv)                         { $status = 'FAILING' }
        elseif ($severeIds -contains $id -and $raw -gt 0)        { $status = 'CRITICAL' }
        elseif ($warnIds -contains $id -and $raw -gt 0)          { $status = 'WARNING' }

        if ($status -ne 'OK') {
            $lvl = if ($status -eq 'FAILING' -or $status -eq 'CRITICAL') { 'CRITICAL' } else { 'WARNING' }
            Add-Issue $lvl "${label}: attribute $id $name = $raw ($status)"
        }

        Write-Colored ($fmt -f $id, $name, $val, $worst, $tv, $raw, $status) (Get-LevelColor $status)
    }
}

# Summary
Write-Host ''
$critical = @($issues | Where-Object { $_.Level -eq 'CRITICAL' })
$warnings = @($issues | Where-Object { $_.Level -eq 'WARNING' })

if ($critical.Count -gt 0) {
    Write-Host ("Status: CRITICAL - {0} critical issue(s)" -f $critical.Count)
    $exitCode = 2
} elseif ($warnings.Count -gt 0) {
    Write-Host ("Status: WARNING - {0} issue(s) found" -f $warnings.Count)
    $exitCode = 1
} elseif (-not $haveData) {
    Write-Host 'Status: UNKNOWN - no SMART data could be read'
    $exitCode = 3
} else {
    Write-Host 'Status: OK'
    $exitCode = 0
}

foreach ($i in $issues) {
    Write-Host ("  - [{0}] {1}" -f $i.Level, $i.Message)
}

exit $exitCode
