# Accept log path parameter or default to script directory
param (
    [string]$LogPath
)

# Write message to console and append to log file with UTF-8 encoding
function Write-Log {
    param (
        [string]$Message
    )
    Write-Host $Message
    Add-Content -Path $LogPath -Value $Message -Encoding utf8
}

function Write-SectionHeader {
    param([string]$Text)
    Write-Log "`n$Text"
}

function Write-Result {
    param(
        [string]$Label,
        [string]$Value,
        [ValidateSet('Good', 'Bad', 'Warn', 'Info')]
        [string]$Level = 'Info'
    )
    Write-Log ("  {0,-30}: {1}" -f $Label, $Value)
}

function Get-FirewallStatus {
    Write-SectionHeader "Firewall Status"
    try {
        Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
            if ($_.Enabled) {
                Write-Result -Label $_.Name -Value 'ENABLED' -Level Good
            } else {
                Write-Result -Label $_.Name -Value 'DISABLED' -Level Bad
            }
        }
    } catch {
        Write-Result -Label 'Firewall' -Value "Unable to query ($($_.Exception.Message))" -Level Warn
    }
}

function Get-RDPStatus {
    Write-SectionHeader "Remote Desktop"
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
}

function Get-SharedFolders {
    Write-SectionHeader "Shared Folders"
    try {
        $shares = Get-SmbShare -ErrorAction Stop
        if ($shares) {
            foreach ($s in $shares) {
                Write-Log "  Share: $($s.Name)"
                Write-Log "    Path: $($s.Path)"
                if ($s.Description) { Write-Log "    Description: $($s.Description)" }
                Write-Log ""
            }
        } else {
            Write-Log "  No shared folders found"
        }
    } catch {
        Write-Result -Label 'Shares' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

function Get-LocalUserAudit {
    Write-SectionHeader "Local Users"
    try {
        $groupMembers = @{}
        Get-LocalGroup | ForEach-Object {
            $groupName = $_.Name
            $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue
            foreach ($m in $members) {
                $nameOnly = $m.Name -split '\\' | Select-Object -Last 1
                if (-not $groupMembers.ContainsKey($nameOnly)) { $groupMembers[$nameOnly] = @() }
                $groupMembers[$nameOnly] += $groupName
            }
        }

        Get-LocalUser | Sort-Object Name | ForEach-Object {
            $userGroups = if ($groupMembers.ContainsKey($_.Name)) { $groupMembers[$_.Name] -join ', ' } else { '' }

            Write-Log "  User: $($_.Name)"
            Write-Log "    Enabled: $($_.Enabled)"
            if ($userGroups) { Write-Log "    Groups: $userGroups" }
            if (-not $_.PasswordRequired) {
                Write-Log "    Password required: False"
            }
            Write-Log ""
        }
    } catch {
        Write-Result -Label 'Local Users' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

function Get-UACStatus {
    Write-SectionHeader "UAC Status"
    try {
        $uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
            -Name EnableLUA, ConsentPromptBehaviorAdmin, PromptOnSecureDesktop -ErrorAction Stop

        if ($uac.EnableLUA -eq 0) {
            Write-Result -Label 'UAC' -Value 'Disabled' -Level Bad
        } else {
            $level = switch ($uac.ConsentPromptBehaviorAdmin) {
                0 { 'Never notify (Low)' }
                1 { 'Prompt for credentials on secure desktop' }
                2 { 'Prompt for consent on secure desktop (High)' }
                3 { 'Prompt for credentials' }
                4 { 'Prompt for consent' }
                5 { 'Notify only when apps try to make changes (Default)' }
                default { 'Unknown' }
            }
            Write-Result -Label 'UAC' -Value 'Enabled' -Level Good
            Write-Result -Label 'UAC Level' -Value $level -Level Info
        }
    } catch {
        Write-Result -Label 'UAC' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

function Get-DefenderStatus {
    Write-SectionHeader "Windows Defender / Antivirus"
    try {
        $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
        if ($defenderService) {
            $svcLevel = if ($defenderService.Status -eq 'Running') { 'Good' } else { 'Bad' }
            Write-Result -Label 'Service status' -Value $defenderService.Status -Level $svcLevel
            Write-Result -Label 'Startup type' -Value $defenderService.StartType -Level Info
        } else {
            Write-Result -Label 'Defender service' -Value 'Not found' -Level Warn
        }

        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $rtLevel = if ($mp.RealTimeProtectionEnabled) { 'Good' } else { 'Bad' }
            Write-Result -Label 'Real-time protection' -Value $mp.RealTimeProtectionEnabled -Level $rtLevel
            Write-Result -Label 'Signature age (days)' -Value $mp.AntivirusSignatureAge -Level Info
        } catch {
            # Get-MpComputerStatus is unavailable on some SKUs (e.g. Server Core) - not an error
        }

        try {
            $avProducts = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntivirusProduct -ErrorAction Stop
            foreach ($av in $avProducts) {
                Write-Result -Label 'Registered AV product' -Value $av.displayName -Level Info
            }
        } catch {
            # SecurityCenter2 namespace isn't present on this SKU - not an error
        }
    } catch {
        Write-Result -Label 'Defender' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

function Get-SmartScreenStatus {
    Write-SectionHeader "SmartScreen Status"
    try {
        $smartScreen = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction Stop
        $status = switch ($smartScreen.SmartScreenEnabled) {
            'Off' { 'Disabled' }
            'RequireAdmin' { 'Enabled (Require Admin)' }
            'Warn' { 'Enabled (Warn)' }
            default { "Unknown: $($smartScreen.SmartScreenEnabled)" }
        }
        $level = if ($smartScreen.SmartScreenEnabled -eq 'Off') { 'Bad' } else { 'Good' }
        Write-Result -Label 'SmartScreen' -Value $status -Level $level
    } catch {
        Write-Result -Label 'SmartScreen' -Value 'Registry key not found or not set' -Level Warn
    }
}

function Get-LSAProtectionStatus {
    Write-SectionHeader "LSA Protection"
    try {
        $lsa = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction Stop
        $level = if ($lsa.RunAsPPL -eq 1) { 'Good' } else { 'Warn' }
        $status = if ($lsa.RunAsPPL -eq 1) { 'Enabled' } else { 'Disabled or not set' }
        Write-Result -Label 'LSA Protection' -Value $status -Level $level
    } catch {
        Write-Result -Label 'LSA Protection' -Value 'Registry key not found' -Level Warn
    }
}

function Get-BitLockerStatus {
    Write-SectionHeader "BitLocker Status"
    $encrypted = 0
    $total = 0

    try {
        $volumes = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $volumes) {
            $total++
            $level = if ($v.VolumeStatus -eq 'FullyEncrypted') { 'Good' } else { 'Bad' }
            Write-Result -Label "Drive $($v.MountPoint)" -Value "$($v.VolumeStatus) ($($v.EncryptionPercentage)%)" -Level $level
            if ($v.VolumeStatus -eq 'FullyEncrypted') { $encrypted++ }
        }
    } catch {
        # Get-BitLockerVolume requires the BitLocker module - fall back to manage-bde
        try {
            $drives = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 } | Sort-Object DeviceID
            foreach ($drive in $drives) {
                $total++
                $bitlockerInfo = manage-bde -status $drive.DeviceID 2>$null
                if ($bitlockerInfo -and ($bitlockerInfo | Select-String 'Percentage Encrypted')) {
                    $percentage = (($bitlockerInfo | Select-String 'Percentage Encrypted') -split ':')[1].Trim()
                    Write-Result -Label "Drive $($drive.DeviceID)" -Value "Encrypted ($percentage)" -Level Good
                    $encrypted++
                } else {
                    Write-Result -Label "Drive $($drive.DeviceID)" -Value 'Not encrypted' -Level Bad
                }
            }
        } catch {
            Write-Result -Label 'BitLocker' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
        }
    }

    if ($total -gt 0) {
        Write-Result -Label 'Encryption summary' -Value "$encrypted of $total drives encrypted" -Level Info
    }
}

function Get-WindowsUpdateStatus {
    Write-SectionHeader "Windows Update"
    try {
        $wua = Get-Service wuauserv -ErrorAction Stop
        Write-Result -Label 'Service status' -Value $wua.Status -Level Info
        Write-Result -Label 'Startup type' -Value $wua.StartType -Level Info
    } catch {
        Write-Result -Label 'Windows Update service' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }

    try {
        $lastUpdate = Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($lastUpdate) {
            Write-Result -Label 'Last update' -Value "$($lastUpdate.HotFixID) - $($lastUpdate.Description)" -Level Info
            Write-Result -Label 'Installed on' -Value $lastUpdate.InstalledOn.ToString('dd/MM/yyyy HH:mm') -Level Info
        } else {
            Write-Result -Label 'Last update' -Value 'No updates found' -Level Warn
        }
    } catch {
        Write-Result -Label 'Windows updates' -Value "Unable to check ($($_.Exception.Message))" -Level Warn
    }
}

function Get-RecentLogins {
    Write-SectionHeader "Last 10 Successful Interactive/Remote Logins"
    try {
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4624 } -MaxEvents 500 -ErrorAction Stop

        $logins = foreach ($e in $events) {
            $xml = [xml]$e.ToXml()
            $data = @{}
            foreach ($n in $xml.Event.EventData.Data) { $data[$n.Name] = $n.'#text' }

            $user = $data['TargetUserName']
            $logonType = $data['LogonType']

            # Logon types: 2 interactive, 3 network, 7 unlock, 10 RDP/remote interactive, 11 cached interactive
            if ($user -and $logonType -in @('2', '3', '7', '10', '11') `
                    -and $user -notmatch '^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-\d+|UMFD-\d+)$' `
                    -and $user -notmatch '\$$') {
                [PSCustomObject]@{
                    Time      = $e.TimeCreated
                    User      = $user
                    LogonType = $logonType
                }
            }
        }

        $logins = $logins | Select-Object -First 10

        if ($logins) {
            foreach ($l in $logins) {
                $time = $l.Time.ToString('dd/MM/yyyy HH:mm:ss')
                Write-Log ("  {0,-22} {1,-20} (type {2})" -f $time, $l.User, $l.LogonType)
            }
        } else {
            Write-Log "  No relevant logon events found in the recent event log window"
        }
    } catch {
        Write-Result -Label 'Login history' -Value "Unable to retrieve ($($_.Exception.Message)) - try running as Administrator" -Level Warn
    }
}

# Execute Functions
Get-FirewallStatus
Get-RDPStatus
Get-SharedFolders
Get-LocalUserAudit
Get-UACStatus
Get-DefenderStatus
Get-SmartScreenStatus
Get-LSAProtectionStatus
Get-BitLockerStatus
Get-WindowsUpdateStatus
Get-RecentLogins
