Write-Host "Active TCP Connections:"
$connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue

if ($connections) {
    # Create formatted header for the connections table
    Write-Host " Local Address".PadRight(25) "Remote Address".PadRight(25) "Process"
    Write-Host " -------------".PadRight(25) "--------------".PadRight(25) "-------"
    
    # Sort connections by local port and display each one
    foreach ($conn in $connections | Sort-Object LocalPort) {
        # Try to get the process name that owns this connection
        $processName = try {
            (Get-Process -Id $conn.OwningProcess -ErrorAction Stop).ProcessName
        }
        catch {
            # If process lookup fails, display "N/A"
            "N/A"
        }
        
        # Format local and remote addresses with port numbers
        $local = "$($conn.LocalAddress):$($conn.LocalPort)"
        $remote = "$($conn.RemoteAddress):$($conn.RemotePort)"
        
        # Display the connection information in formatted columns
        Write-Host " $($local.PadRight(25)) $($remote.PadRight(25)) $processName"
    }
}
else {
    Write-Host " No established connections found"
}

# Get all running processes to map process IDs to names later
$procs = Get-Process | Select-Object Id, ProcessName

# Display TCP ports that are listening (open for incoming connections)
Write-Host "`nTCP Ports:"
Write-Host " Port".PadRight(10) "Process"
Write-Host " ----".PadRight(10) "-------"

# Get all TCP connections in Listen state (open ports waiting for connections)
$tcp = Get-NetTCPConnection -State Listen |
       Select-Object LocalPort, OwningProcess -Unique |  # Remove duplicates
       Sort-Object LocalPort  # Sort by port number

# Display each listening TCP port with its associated process
$tcp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(10)) $($procName -or 'Unknown')"
}

# Display UDP ports that are open (UDP is connectionless, so no "listening" state)
Write-Host "`nUDP Ports:"
Write-Host " Port".PadRight(10) "Process"
Write-Host " ----".PadRight(10) "-------"

# Get all UDP endpoints (open UDP ports)
$udp = Get-NetUDPEndpoint |
       Select-Object LocalPort, OwningProcess -Unique |  # Remove duplicates
       Sort-Object LocalPort  # Sort by port number

# Display each open UDP port with its associated process
$udp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(10)) $($procName -or 'Unknown')"
}

# Display Windows Firewall status for all profiles
Write-Host "`nFirewall Status:"
# Get firewall settings for Domain, Private, and Public profiles
Get-NetFirewallProfile | ForEach-Object {
    $status = if ($_.Enabled) { 'ENABLED' } else { 'DISABLED' }
    Write-Host " $($_.Name): $status"
}

# Display Remote Desktop Protocol (RDP) configuration status
Write-Host "`nRemote Desktop Status:"
try {
    # Check RDP status from Windows Registry
    $rdp = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop
    # fDenyTSConnections: 0 = RDP enabled, 1 = RDP disabled
    $status = if ($rdp.fDenyTSConnections -eq 0) { 'Enabled' } else { 'Disabled' }
    Write-Host " RDP: $status"
} catch {
    Write-Host " Unable to check RDP status: $_"
}

# Display shared folders (SMB shares) on the system
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
# Create a hashtable to map users to their group memberships
$groupMembers = @{}

# Get all local groups and their members
Get-LocalGroup | ForEach-Object {
    $groupName = $_.Name
    $members = Get-LocalGroupMember -Group $groupName -ErrorAction SilentlyContinue
    foreach ($m in $members) {
        # Extract username from domain\username format
        $nameOnly = $m.Name -split '\\' | Select-Object -Last 1
        if (-not $groupMembers.ContainsKey($nameOnly)) {
            $groupMembers[$nameOnly] = @()
        }
        $groupMembers[$nameOnly] += $groupName
    }
}

# Display all local users with their properties
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
    Write-Host ""  # Empty line between users for readability
}

Write-Host "UAC Status:"
try {
    # Read UAC settings from Windows Registry
    $uac = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
        -Name EnableLUA, ConsentPromptBehaviorAdmin, PromptOnSecureDesktop -ErrorAction Stop

    # Check if UAC is enabled (EnableLUA = 0 means disabled)
    if ($uac.EnableLUA -eq 0) {
        Write-Host "  UAC: Disabled"
    } else {
        # Determine UAC level based on ConsentPromptBehaviorAdmin value
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
    # Check Windows Defender service (WinDefend) status and startup type
    $defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
    if ($defenderService) {
        Write-Host "  Service status: $($defenderService.Status)"      # Running, Stopped, etc.
        Write-Host "  Startup type: $($defenderService.StartType)"    # Automatic, Manual, Disabled
    }
    else {
        Write-Host " Service not found"  # Windows Defender might not be installed or named differently
    }
}
catch {
    Write-Host " Unable to check Windows Defender: $_"
}

Write-Host "`nSmartScreen Status:"
try {
    # Check SmartScreen settings from Windows Registry
    $smartScreen = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction SilentlyContinue
    if ($smartScreen) {
        # Interpret SmartScreen values
        $status = switch ($smartScreen.SmartScreenEnabled) {
            'Off' { 'Disabled' }                          # SmartScreen turned off
            'RequireAdmin' { 'Enabled (Require Admin)' }  # Requires admin approval
            'Warn' { 'Enabled (Warn)' }                   # Shows warning but allows
            default { "Unknown: $($smartScreen.SmartScreenEnabled)" }  # Unknown value
        }
        Write-Host " SmartScreen: $status"  # Display SmartScreen status
    }
    else {
        Write-Host " Registry key not found or not set"  # Key doesn't exist or value not set
    }
}
catch {
    Write-Host " Unable to check SmartScreen: $_"
}

# Display Local Security Authority (LSA) protection status
Write-Host "`nLSA Protection:"
try {
    # Check LSA protection (credential guard) from registry
    $lsa = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction SilentlyContinue
    if ($lsa) {
        # RunAsPPL = 1 means LSA protection is enabled
        $status = if ($lsa.RunAsPPL -eq 1) { 'Enabled' } else { 'Disabled or Not Set' }
        Write-Host "  LSA Protection: $status"  # Display LSA protection status
    }
    else {
        Write-Host " Registry key not found"
    }
}
catch {
    Write-Host " Unable to check LSA protection: $_"
}

# Display BitLocker disk encryption status
Write-Host "`nBitLocker Status:"
# Get all fixed drives (type 3 = local disk)
$drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Sort-Object DeviceID
$encryptedDrives = 0
$totalDrives = 0

# Check encryption status for each drive
foreach ($drive in $drives) {
    $totalDrives++
    Write-Host " Drive $($drive.DeviceID):"  # Display drive letter (e.g., C:)
    try {
        # Use manage-bde command-line tool to check BitLocker status
        $bitlockerInfo = manage-bde -status $drive.DeviceID 2>$null  # Suppress error output
        
        # Check if the drive is encrypted by looking for percentage encrypted line
        if ($bitlockerInfo -and ($bitlockerInfo | Select-String 'Percentage Encrypted')) {
            $percentageLine = $bitlockerInfo | Select-String 'Percentage Encrypted'
            $percentage = ($percentageLine -split ":")[1].Trim()  # Extract percentage value
            Write-Host "  Status: Encrypted"
            Write-Host "  Percentage: $percentage"
            $encryptedDrives++  # Increment encrypted drive counter
        }
        else {
            Write-Host "  Status: Not encrypted"  # Drive is not BitLocker encrypted
        }
    }
    catch {
        Write-Host " Error: Cannot check BitLocker status"  # manage-bde command failed
    }
    Write-Host ""  # Empty line for readability
}

Write-Host "  Encryption Summary: $encryptedDrives of $totalDrives drives encrypted"  # Summary line

# Display Windows Update service status
Write-Host "`nWindows Update Service Status:"
try {
    # Check Windows Update service (wuauserv) status
    $wua = Get-Service wuauserv -ErrorAction Stop
    Write-Host " Service: $($wua.Status)"  # Running, Stopped, etc.
} catch {
    Write-Host " Unable to check Windows Update service: $_"
}

# Display information about the most recent Windows Update
Write-Host "`nLast Windows Update Installed:"
try {
    # Get the most recent hotfix (Windows Update) sorted by installation date
    $lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($lastUpdate) {
        Write-Host " HotFixID: $($lastUpdate.HotFixID)"  # Update identifier (e.g., KB1234567)
        Write-Host " Description: $($lastUpdate.Description)"  # Update description
        Write-Host " Installed On: $($lastUpdate.InstalledOn.ToString('dd/MM/yyyy HH:mm'))"  # Installation timestamp
    }
    else {
        Write-Host " No updates found"  # No hotfixes found in system
    }
}
catch {
    Write-Host " Unable to check Windows updates: $_"
}

# Display the last 10 successful user logins from Security event log
Write-Host "`nLast 10 Successful Logins:"
try {
    # Query Security event log for successful logon events (Event ID 4624)
    $successLogins = Get-EventLog -LogName Security -ErrorAction Stop |
                     Where-Object { $_.EventID -eq 4624 } |  # Event ID 4624 = Successful logon
                     ForEach-Object {
                         $user = $_.ReplacementStrings[5]  # Extract username from event data
                         # Filter out system accounts and special users
                         if ($user -and $user -notmatch '^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-\d+|UMFD-\d+|\$)$') {
                             [PSCustomObject]@{
                                 Time = $_.TimeGenerated
                                 User = $user
                             }
                         }
                     } |
                     Select-Object -Last 10 |  # Get only the 10 most recent
                     Sort-Object Time -Descending  # Sort newest to oldest

    if ($successLogins) {
        # Display each login with formatted timestamp and username
        $successLogins | ForEach-Object {
            $time = $_.Time.ToString("dd/MM/yyyy HH:mm:ss")
            Write-Host " $($time.PadRight(22)) $($_.User)"  # Aligned columns
        }
    } else {
        Write-Host " No successful login events found"  # No relevant events in log
    }
} catch {
    Write-Host " Unable to retrieve login events: $_"  # Event log access failed
}