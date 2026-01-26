Write-Host "Active TCP Connections:"
$connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue

if ($connections) {
    Write-Host " Local Address".PadRight(25) "Remote Address".PadRight(25) "Process"
    Write-Host " -------------".PadRight(25) "--------------".PadRight(25) "-------"
    foreach ($conn in $connections | Sort-Object LocalPort) {
        $processName = try {
            (Get-Process -Id $conn.OwningProcess -ErrorAction Stop).ProcessName
        }
        catch {
            "N/A"
        }
        
        $local = "$($conn.LocalAddress):$($conn.LocalPort)"
        $remote = "$($conn.RemoteAddress):$($conn.RemotePort)"
        
        Write-Host " $($local.PadRight(25)) $($remote.PadRight(25)) $processName"
    }
}
else {
    Write-Host " No established connections found"
}

$procs = Get-Process | Select-Object Id, ProcessName

Write-Host "`nTCP Ports:"
Write-Host " Port".PadRight(10) "Process"
Write-Host " ----".PadRight(10) "-------"
$tcp = Get-NetTCPConnection -State Listen |
       Select-Object LocalPort, OwningProcess -Unique |
       Sort-Object LocalPort

$tcp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(10)) $($procName -or 'Unknown')"
}

Write-Host "`nUDP Ports:"
Write-Host " Port".PadRight(10) "Process"
Write-Host " ----".PadRight(10) "-------"
$udp = Get-NetUDPEndpoint |
       Select-Object LocalPort, OwningProcess -Unique |
       Sort-Object LocalPort

$udp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(10)) $($procName -or 'Unknown')"
}

Write-Host "`nFirewall Status:"
Get-NetFirewallProfile | ForEach-Object {
    $status = if ($_.Enabled) { 'ENABLED' } else { 'DISABLED' }
    Write-Host " $($_.Name): $status"
}

Write-Host "`nRemote Desktop Status:"
try {
    $rdp = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop
    $status = if ($rdp.fDenyTSConnections -eq 0) { 'Enabled' } else { 'Disabled' }
    Write-Host " RDP: $status"
} catch {
    Write-Host " Unable to check RDP status: $_"
}

Write-Host "`nShared Folders:"
$shares = Get-SmbShare -ErrorAction SilentlyContinue
if ($shares) {
    $shares | ForEach-Object {
        Write-Host " Share: $($_.Name)"
        Write-Host "  Path: $($_.Path)"
        if ($_.Description) {
            Write-Host "  Description: $($_.Description)"
        }
        Write-Host ""
    }
} else {
    Write-Host " No shared folders found"
}

Write-Host "`nLocal Users:"
$groupMembers = @{}
Get-LocalGroup | ForEach-Object {
    $groupName = $_.Name
    $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        $nameOnly = $m.Name -split '\\' | Select-Object -Last 1
        if (-not $groupMembers.ContainsKey($nameOnly)) {
            $groupMembers[$nameOnly] = @()
        }
        $groupMembers[$nameOnly] += $groupName
    }
}

Get-LocalUser | Sort-Object Name | ForEach-Object {
    $userGroups = if ($groupMembers.ContainsKey($_.Name)) {
        $groupMembers[$_.Name] -join ", "
    } else {
        ""
    }
    
    Write-Host " User: $($_.Name)"
    Write-Host "  Enabled: $($_.Enabled)"
    if ($userGroups) {
        Write-Host "  Groups: $userGroups"
    }
    Write-Host ""
}

Write-Host "UAC Status:"
try {
    $uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
        -Name EnableLUA, ConsentPromptBehaviorAdmin, PromptOnSecureDesktop -ErrorAction Stop

    if ($uac.EnableLUA -eq 0) {
        Write-Host "  UAC: Disabled"
    } else {
        $level = switch ($uac.ConsentPromptBehaviorAdmin) {
            0 { "Never notify (Low)" }
            1 { "Prompt for credentials on secure desktop" }
            2 { "Prompt for consent on secure desktop (High)" }
            3 { "Prompt for credentials" }
            4 { "Prompt for consent" }
            5 { "Notify only when apps try to make changes (Default)" }
            default { "Unknown" }
        }
        Write-Host " UAC: Enabled"
        Write-Host " Level: $level"
    }
} catch {
    Write-Host " Unable to check UAC: $_"
}

Write-Host "`nWindows Defender Status:"
try {
    $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($defenderService) {
        Write-Host "  Service status: $($defenderService.Status)"
        Write-Host "  Startup type: $($defenderService.StartType)"
    }
    else {
        Write-Host " Service not found"
    }
}
catch {
    Write-Host " Unable to check Windows Defender: $_"
}

Write-Host "`nSmartScreen Status:"
try {
    $smartScreen = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction SilentlyContinue
    if ($smartScreen) {
        $status = switch ($smartScreen.SmartScreenEnabled) {
            'Off' { 'Disabled' }
            'RequireAdmin' { 'Enabled (Require Admin)' }
            'Warn' { 'Enabled (Warn)' }
            default { "Unknown: $($smartScreen.SmartScreenEnabled)" }
        }
        Write-Host " SmartScreen: $status"
    }
    else {
        Write-Host " Registry key not found or not set"
    }
}
catch {
    Write-Host " Unable to check SmartScreen: $_"
}

Write-Host "`nLSA Protection:"
try {
    $lsa = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction SilentlyContinue
    if ($lsa) {
        $status = if ($lsa.RunAsPPL -eq 1) { 'Enabled' } else { 'Disabled or Not Set' }
        Write-Host "  LSA Protection: $status"
    }
    else {
        Write-Host " Registry key not found"
    }
}
catch {
    Write-Host " Unable to check LSA protection: $_"
}

Write-Host "`nBitLocker Status:"
$drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Sort-Object DeviceID
$encryptedDrives = 0
$totalDrives = 0

foreach ($drive in $drives) {
    $totalDrives++
    Write-Host " Drive $($drive.DeviceID):"
    try {
        $bitlockerInfo = manage-bde -status $drive.DeviceID 2>$null
        
        if ($bitlockerInfo -and ($bitlockerInfo | Select-String 'Percentage Encrypted')) {
            $percentageLine = $bitlockerInfo | Select-String 'Percentage Encrypted'
            $percentage = ($percentageLine -split ":")[1].Trim()
            Write-Host "  Status: Encrypted"
            Write-Host "  Percentage: $percentage"
            $encryptedDrives++
        }
        else {
            Write-Host "  Status: Not encrypted"
        }
    }
    catch {
        Write-Host " Error: Cannot check BitLocker status"
    }
    Write-Host ""
}

Write-Host "  Encryption Summary: $encryptedDrives of $totalDrives drives encrypted"

Write-Host "`nWindows Update Service Status:"
try {
    $wua = Get-Service wuauserv -ErrorAction Stop
    Write-Host " Service: $($wua.Status)"
} catch {
    Write-Host " Unable to check Windows Update service: $_"
}

Write-Host "`nLast Windows Update Installed:"
try {
    $lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($lastUpdate) {
        Write-Host " HotFixID: $($lastUpdate.HotFixID)"
        Write-Host " Description: $($lastUpdate.Description)"
        Write-Host " Installed On: $($lastUpdate.InstalledOn.ToString('dd/MM/yyyy HH:mm'))"
    }
    else {
        Write-Host " No updates found"
    }
}
catch {
    Write-Host " Unable to check Windows updates: $_"
}

Write-Host "`nLast 10 Successful Logins:"
try {
    $successLogins = Get-EventLog -LogName Security -ErrorAction Stop |
                     Where-Object { $_.EventID -eq 4624 } |
                     ForEach-Object {
                         $user = $_.ReplacementStrings[5]
                         if ($user -and $user -notmatch '^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-\d+|UMFD-\d+|\$)$') {
                             [PSCustomObject]@{
                                 Time = $_.TimeGenerated
                                 User = $user
                             }
                         }
                     } |
                     Select-Object -Last 10 |
                     Sort-Object Time -Descending

    if ($successLogins) {
        $successLogins | ForEach-Object {
            $time = $_.Time.ToString("dd/MM/yyyy HH:mm:ss")
            Write-Host " $($time.PadRight(22)) $($_.User)"
        }
    } else {
        Write-Host " No successful login events found"
    }
} catch {
    Write-Host " Unable to retrieve login events: $_"
}