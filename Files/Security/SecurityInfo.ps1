param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# InvariantCulture: avoids Hijri calendar / localized digits on Arabic systems
function Format-Date {
    param ($Date, [string]$Format = 'dd/MM/yyyy HH:mm')
    if ($Date -is [datetime]) { $Date.ToString($Format, [cultureinfo]::InvariantCulture) } else { "$Date" }
}

function Write-Result {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Label,

        # Empty/null values must not throw (e.g. a missing display name)
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Good', 'Bad', 'Warn', 'Info')]
        [string]$Level = 'Info'
    )

    if ([string]::IsNullOrEmpty($Value)) { $Value = 'n/a' }
    Write-Log ("  {0,-30}: {1}" -f $Label, $Value) -Level $Level
}

function Test-NoEventsFound($ErrorRecord) {
    $ErrorRecord.FullyQualifiedErrorId -like '*NoMatchingEventsFound*'
}

Write-Log "Firewall Status"
try {
    foreach ($p in Get-NetFirewallProfile -ErrorAction Stop) {
        # 'Enabled' is a GpoBoolean (True / False / NotConfigured), so compare the text
        switch ("$($p.Enabled)") {
            'True'  { Write-Result -Label $p.Name -Value 'ENABLED' -Level Good }
            'False' { Write-Result -Label $p.Name -Value 'DISABLED' -Level Bad }
            default { Write-Result -Label $p.Name -Value "NOT CONFIGURED ($($p.Enabled))" -Level Warn }
        }
    }
} catch {
    Write-Result -Label 'Firewall' -Value "Unable to query ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nRemote Desktop"
try {
    $rdp = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop
    if ($rdp.fDenyTSConnections -eq 0) {
        Write-Result -Label 'RDP' -Value 'Enabled' -Level Warn

        try {
            $nla = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction Stop
            if ($nla.UserAuthentication -eq 1) {
                Write-Result -Label 'RDP Network Level Auth' -Value 'Required' -Level Good
            } else {
                Write-Result -Label 'RDP Network Level Auth' -Value 'Not required' -Level Bad
            }
        } catch {
            Write-Result -Label 'RDP Network Level Auth' -Value 'Unable to determine' -Level Warn
        }
    } else {
        Write-Result -Label 'RDP' -Value 'Disabled' -Level Good
    }
} catch {
    Write-Result -Label 'RDP' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nShared Folders"
try {
    $shares  = @(Get-SmbShare -ErrorAction Stop)
    $custom  = @($shares | Where-Object { -not $_.Special })   # ADMIN$, C$, IPC$ are "Special"
    Write-Result -Label 'Shares (total / custom)' -Value "$($shares.Count) / $($custom.Count)" -Level Info

    foreach ($s in $custom) {
        Write-Log "  Share: $($s.Name)"
        Write-Log "    Path: $($s.Path)"
        if ($s.Description) { Write-Log "    Description: $($s.Description)" }

        $open = @(Get-SmbShareAccess -Name $s.Name -ErrorAction SilentlyContinue |
            Where-Object { $_.AccountName -match 'Everyone|ANONYMOUS' -and "$($_.AccessControlType)" -eq 'Allow' -and "$($_.AccessRight)" -in 'Full', 'Change' })
        foreach ($a in $open) {
            Write-Result -Label "  $($s.Name) access" -Value "$($a.AccountName): $($a.AccessRight)" -Level Warn
        }
        Write-Log ''
    }
} catch {
    Write-Result -Label 'Shares' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nLocal Users"
try {
    # Key by SID, not by name: a domain account named "admin" must not
    # be confused with the local account "admin"
    $groupMembers = @{}
    foreach ($g in Get-LocalGroup -ErrorAction Stop) {
        foreach ($m in @(Get-LocalGroupMember -Group $g.Name -ErrorAction SilentlyContinue)) {
            $key = $m.SID.Value
            if (-not $groupMembers.ContainsKey($key)) {
                $groupMembers[$key] = New-Object System.Collections.Generic.List[string]
            }
            $groupMembers[$key].Add($g.Name)
        }
    }

    foreach ($u in (Get-LocalUser -ErrorAction Stop | Sort-Object Name)) {
        $sid    = $u.SID.Value
        $groups = if ($groupMembers.ContainsKey($sid)) { $groupMembers[$sid] -join ', ' } else { '' }

        Write-Log "  User: $($u.Name)"
        Write-Log "    Enabled: $($u.Enabled)"
        if ($groups) { Write-Log "    Groups: $groups" }
        Write-Log "    Last logon: $(if ($u.LastLogon) { Format-Date $u.LastLogon } else { 'never' })"
        Write-Log "    Password last set: $(if ($u.PasswordLastSet) { Format-Date $u.PasswordLastSet } else { 'never' })"

        if ($u.Enabled -and -not $u.PasswordRequired) {
            Write-Result -Label "  $($u.Name)" -Value 'Enabled and password NOT required' -Level Bad
        }
        if ($u.Enabled -and $sid -like '*-501') {
            Write-Result -Label "  $($u.Name)" -Value 'Built-in Guest account is enabled' -Level Bad
        }
        Write-Log ''
    }
} catch {
    Write-Result -Label 'Local Users' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nUAC Status"
try {
    # Read the whole key: a missing value (e.g. PromptOnSecureDesktop) must not abort the check
    $uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop

    if ($uac.EnableLUA -eq 0) {
        Write-Result -Label 'UAC' -Value 'Disabled' -Level Bad
    } else {
        $behavior = if ($null -ne $uac.ConsentPromptBehaviorAdmin) { [int]$uac.ConsentPromptBehaviorAdmin } else { 5 }
        $secure   = if ($null -ne $uac.PromptOnSecureDesktop)      { [int]$uac.PromptOnSecureDesktop }      else { 1 }

        $text  = 'Unknown'
        $level = 'Info'
        switch ($behavior) {
            0 { $text = 'Elevate without prompting (never notify)'; $level = 'Bad' }
            1 { $text = 'Prompt for credentials on secure desktop' }
            2 { $text = 'Prompt for consent on secure desktop (Always notify)' }
            3 { $text = 'Prompt for credentials' }
            4 { $text = 'Prompt for consent' }
            5 {
                if ($secure -eq 0) { $text = 'Notify only for app changes, without dimming the desktop'; $level = 'Warn' }
                else               { $text = 'Notify only when apps try to make changes (Default)' }
            }
        }
        Write-Result -Label 'UAC' -Value 'Enabled' -Level Good
        Write-Result -Label 'UAC Level' -Value $text -Level $level
    }
} catch {
    Write-Result -Label 'UAC' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nWindows Defender / Antivirus"

# Registered products (also tells us whether a third-party AV is active)
$avList = @()
try {
    $avList = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntivirusProduct -ErrorAction Stop)
} catch {
    # SecurityCenter2 isn't present on Server SKUs - not an error
}

$anyActive = $false
foreach ($av in $avList) {
    $on  = ($av.productState -band 0x1000) -ne 0
    $old = ($av.productState -band 0x10) -ne 0
    if ($on) { $anyActive = $true }
    $state = '{0}, signatures {1}' -f $(if ($on) { 'ON' } else { 'OFF' }), $(if ($old) { 'OUT OF DATE' } else { 'up to date' })
    Write-Result -Label 'Registered AV product' -Value "$($av.displayName) - $state" -Level Info
}

# Defender itself. When another AV is active Defender goes passive, so don't flag that as bad
try {
    $svc = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($svc) {
        $svcLevel = if ($svc.Status -eq 'Running') { 'Good' } elseif ($anyActive) { 'Info' } else { 'Bad' }
        Write-Result -Label 'Defender service' -Value "$($svc.Status) (startup: $($svc.StartType))" -Level $svcLevel
    } else {
        Write-Result -Label 'Defender service' -Value 'Not found' -Level Info
    }

    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $rtLevel = if ($mp.RealTimeProtectionEnabled) { 'Good' } elseif ($anyActive) { 'Info' } else { 'Bad' }
        Write-Result -Label 'Real-time protection' -Value $mp.RealTimeProtectionEnabled -Level $rtLevel

        $ageLevel = if ($mp.AntivirusSignatureAge -gt 7) { 'Warn' } else { 'Info' }
        Write-Result -Label 'Signature age (days)' -Value $mp.AntivirusSignatureAge -Level $ageLevel

        if ($null -ne $mp.IsTamperProtected) {
            $tpLevel = if ($mp.IsTamperProtected) { 'Good' } else { 'Warn' }
            Write-Result -Label 'Tamper protection' -Value $mp.IsTamperProtected -Level $tpLevel
        }
    } catch {
        # Get-MpComputerStatus is unavailable on some SKUs (e.g. Server Core) - not an error
    }
} catch {
    Write-Result -Label 'Defender' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

# Overall verdict (only when Security Center data is available)
if ($avList.Count -gt 0) {
    if ($anyActive) { Write-Result -Label 'Active protection' -Value 'Yes' -Level Good }
    else            { Write-Result -Label 'Active protection' -Value 'NONE - no antivirus is active' -Level Bad }
}

Write-Log "`nSmartScreen Status"
try {
    $policy = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name EnableSmartScreen -ErrorAction SilentlyContinue
    if ($policy -and $policy.EnableSmartScreen -eq 0) {
        Write-Result -Label 'SmartScreen (policy)' -Value 'Disabled by policy' -Level Bad
    } else {
        $value = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction Stop).SmartScreenEnabled
        switch ($value) {
            'Off'          { Write-Result -Label 'SmartScreen' -Value 'Disabled' -Level Bad }
            'RequireAdmin' { Write-Result -Label 'SmartScreen' -Value 'Enabled (Require Admin)' -Level Good }
            'Warn'         { Write-Result -Label 'SmartScreen' -Value 'Enabled (Warn)' -Level Good }
            'Prompt'       { Write-Result -Label 'SmartScreen' -Value 'Enabled (Prompt)' -Level Good }
            'On'           { Write-Result -Label 'SmartScreen' -Value 'Enabled' -Level Good }
            default        { Write-Result -Label 'SmartScreen' -Value "Unknown: $value" -Level Warn }
        }
    }
} catch {
    Write-Result -Label 'SmartScreen' -Value 'Registry value not found or not set' -Level Warn
}

Write-Log "`nLSA Protection"
try {
    # Read the whole key: a missing RunAsPPL means "not enabled", not "key not found"
    $lsa = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -ErrorAction Stop
    # 1 = enabled with UEFI lock, 2 = enabled without lock (Windows 11 22H2+)
    if ($lsa.RunAsPPL -in 1, 2) {
        Write-Result -Label 'LSA Protection' -Value "Enabled (RunAsPPL = $($lsa.RunAsPPL))" -Level Good
    } else {
        Write-Result -Label 'LSA Protection' -Value 'Disabled or not set' -Level Warn
    }
} catch {
    Write-Result -Label 'LSA Protection' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nBitLocker Status"
$encrypted = 0
$total     = 0
$done      = $false

try {
    foreach ($v in @(Get-BitLockerVolume -ErrorAction Stop)) {
        $total++
        $detail = "$($v.VolumeStatus) ($($v.EncryptionPercentage)%), protection $($v.ProtectionStatus)"
        if ($v.VolumeStatus -eq 'FullyEncrypted') {
            $encrypted++
            # Encrypted but protection suspended is not really protected
            $level = if ("$($v.ProtectionStatus)" -eq 'On') { 'Good' } else { 'Warn' }
        } elseif ("$($v.VolumeStatus)" -match 'InProgress|Paused') {
            $level = 'Warn'
        } else {
            $level = 'Bad'
        }
        Write-Result -Label "Drive $($v.MountPoint)" -Value $detail -Level $level
    }
    $done = $true
} catch {
    # BitLocker module missing (e.g. Home edition) - fall back to WMI below
}

if (-not $done) {
    # Locale-independent fallback (manage-bde output is localized and reports 0% for unencrypted drives)
    $total = 0
    $encrypted = 0
    try {
        $ns = 'root/CIMV2/Security/MicrosoftVolumeEncryption'
        $vols = @(Get-CimInstance -Namespace $ns -ClassName Win32_EncryptableVolume -ErrorAction Stop | Sort-Object DriveLetter)
        foreach ($v in $vols) {
            $total++
            $conv = Invoke-CimMethod -InputObject $v -MethodName GetConversionStatus -Arguments @{ PrecisionFactor = 0 } -ErrorAction Stop
            $prot = Invoke-CimMethod -InputObject $v -MethodName GetProtectionStatus -ErrorAction Stop

            $status = switch ([int]$conv.ConversionStatus) {
                0 { 'FullyDecrypted' }
                1 { 'FullyEncrypted' }
                2 { 'EncryptionInProgress' }
                3 { 'DecryptionInProgress' }
                4 { 'EncryptionPaused' }
                5 { 'DecryptionPaused' }
                default { 'Unknown' }
            }
            $protText = switch ([int]$prot.ProtectionStatus) { 0 { 'Off' } 1 { 'On' } default { 'Unknown' } }

            if ($status -eq 'FullyEncrypted') {
                $encrypted++
                $level = if ($protText -eq 'On') { 'Good' } else { 'Warn' }
            } elseif ($status -match 'InProgress|Paused') {
                $level = 'Warn'
            } else {
                $level = 'Bad'
            }
            $name = if ($v.DriveLetter) { $v.DriveLetter } else { $v.DeviceID }
            Write-Result -Label "Drive $name" -Value "$status ($($conv.EncryptionPercentage)%), protection $protText" -Level $level
        }
    } catch {
        Write-Result -Label 'BitLocker' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

if ($total -gt 0) {
    Write-Result -Label 'Encryption summary' -Value "$encrypted of $total drives fully encrypted" -Level Info
}

Write-Log "`nWindows Update"
try {
    $wua = Get-Service wuauserv -ErrorAction Stop
    # The service is trigger-started, so "Stopped" is normal
    Write-Result -Label 'Service status' -Value $wua.Status -Level Info
    Write-Result -Label 'Startup type' -Value $wua.StartType -Level Info
} catch {
    Write-Result -Label 'Windows Update service' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

$rebootPending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                 (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
if ($rebootPending) { Write-Result -Label 'Reboot pending' -Value 'Yes' -Level Warn }
else                { Write-Result -Label 'Reboot pending' -Value 'No' -Level Good }

# The Windows Update Agent COM API reflects Cumulative Updates that Get-HotFix often misses.
$reported = $false
try {
    $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
    $count    = $searcher.GetTotalHistoryCount()

    if ($count -gt 0) {
        # History is newest-first; 200 entries is plenty and avoids loading the whole history
        $last = $searcher.QueryHistory(0, [math]::Min($count, 200)) |
            Where-Object { $_.ResultCode -eq 2 -and $_.Title -notmatch 'Security Intelligence|Definition Update|Microsoft Defender Antivirus' } |
            Sort-Object Date -Descending |
            Select-Object -First 1

        if ($last) {
            $age   = [int]((Get-Date) - $last.Date).TotalDays
            $level = if ($age -gt 45) { 'Warn' } else { 'Good' }
            Write-Result -Label 'Last update' -Value $last.Title -Level Info
            Write-Result -Label 'Installed on' -Value ("{0} ({1} days ago)" -f (Format-Date $last.Date), $age) -Level $level
            $reported = $true
        }
    }
} catch {
    # COM API unavailable or blocked - fall back below
}

if (-not $reported) {
    try {
        $hotfix = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hotfix) {
            Write-Result -Label 'Last update' -Value "$($hotfix.HotFixID) - $($hotfix.Description)" -Level Info
            Write-Result -Label 'Installed on' -Value (Format-Date $hotfix.InstalledOn) -Level Info
        } else {
            Write-Result -Label 'Last update' -Value 'No updates found' -Level Warn
        }
    } catch {
        Write-Result -Label 'Windows updates' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

Write-Log "`nPlatform Security"

try {
    $smb1 = (Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol
    if ($smb1) { Write-Result -Label 'SMBv1 server' -Value 'Enabled' -Level Bad }
    else       { Write-Result -Label 'SMBv1 server' -Value 'Disabled' -Level Good }
} catch {
    Write-Result -Label 'SMBv1 server' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

try {
    if (Confirm-SecureBootUEFI -ErrorAction Stop) { Write-Result -Label 'Secure Boot' -Value 'Enabled' -Level Good }
    else                                          { Write-Result -Label 'Secure Boot' -Value 'Disabled' -Level Warn }
} catch {
    Write-Result -Label 'Secure Boot' -Value 'Unavailable (legacy BIOS or insufficient rights)' -Level Warn
}

try {
    $tpm = Get-Tpm -ErrorAction Stop
    if ($tpm.TpmPresent -and $tpm.TpmReady) { Write-Result -Label 'TPM' -Value 'Present and ready' -Level Good }
    elseif ($tpm.TpmPresent)                { Write-Result -Label 'TPM' -Value 'Present but not ready' -Level Warn }
    else                                    { Write-Result -Label 'TPM' -Value 'Not present' -Level Warn }
} catch {
    Write-Result -Label 'TPM' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
}

Write-Log "`nLast 10 Successful Interactive/Remote Logins"

# Network logons (type 3) are extremely noisy (file shares, machine accounts) and slow the query down.
# Set to $true to include them.
$includeNetworkLogons = $false

$typeNames = @{ 2 = 'Interactive'; 3 = 'Network'; 7 = 'Unlock'; 10 = 'RemoteInteractive'; 11 = 'CachedInteractive' }
$logonTypes = if ($includeNetworkLogons) { 2, 3, 7, 10, 11 } else { 2, 7, 10, 11 }

try {
    # Filter on the server side (inside the event log service) instead of pulling and parsing
    # thousands of events in PowerShell. System/service logons are excluded by their domain.
    $typeFilter = ($logonTypes | ForEach-Object { "Data[@Name='LogonType']='$_'" }) -join ' or '
    $xpath = "*[System[EventID=4624]] and *[EventData[($typeFilter) and " +
             "Data[@Name='TargetDomainName']!='NT AUTHORITY' and " +
             "Data[@Name='TargetDomainName']!='Window Manager' and " +
             "Data[@Name='TargetDomainName']!='Font Driver Host']]"

    # Small batch: only machine accounts ("name$") are left to drop on the client side
    $events = Get-WinEvent -LogName Security -FilterXPath $xpath -MaxEvents 40 -ErrorAction Stop

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($e in $events) {
        $p    = $e.Properties
        $user = $p[5].Value
        if (-not $user -or $user -like '*$') { continue }

        $logonType = [int]$p[8].Value
        $source = $p[18].Value
        if (-not $source) { $source = '-' }
        $rows.Add([pscustomobject]@{
            Time   = $e.TimeCreated
            User   = "$($p[6].Value)\$user"
            Type   = "$logonType ($($typeNames[$logonType]))"
            Source = $source
        })
        if ($rows.Count -ge 10) { break }
    }

    if ($rows.Count -eq 0) {
        Write-Log '  No relevant logon events found'
    } else {
        foreach ($r in $rows) {
            Write-Log ('  {0,-20} {1,-28} {2,-22} {3}' -f (Format-Date $r.Time 'dd/MM/yyyy HH:mm:ss'), $r.User, $r.Type, $r.Source)
        }
    }
} catch {
    if (Test-NoEventsFound $_) {
        Write-Log '  No logon events found'
    } else {
        Write-Result -Label 'Login history' -Value "Unable to retrieve ($($_.Exception.Message))" -Level Warn
    }
}
