# Display current user information
Write-Host "Username: $env:USERNAME"
Write-Host "Domain: $env:USERDOMAIN"

# Test basic internet connectivity using Google's public DNS server
Write-Host "`nConnection tests:"
if (Test-Connection -ComputerName "8.8.8.8" -Count 3 -Quiet -ErrorAction SilentlyContinue) {
    Write-Host " Connected"
}
else {
    Write-Host " Disconnected"
}

# Retrieve and display the default gateway (router) IP address
Write-Host "`nDefault Gateway Address:"

# '0.0.0.0/0' represents the default route in routing tables
$gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop
if ($gateway) {
    Write-Host " $gateway"
} else {
    Write-Host " Not found"
}

Write-Host "`nPublic IP Address (WAN):"
# Set security protocol to TLS 1.2 for secure web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$publicIP = $null
# Use ipify.org API to get public IP address in JSON format
$publicIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -ErrorAction SilentlyContinue

if ($publicIP -and $publicIP.ip) {
    Write-Host " IP Address: $($publicIP.ip)"
    
    try {
        # Use ip-api.com to get geolocation information for the public IP
        $geoInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($publicIP.ip)" -ErrorAction SilentlyContinue
        
        if ($geoInfo) {
            Write-Host " Country: $($geoInfo.country)"
            Write-Host " City: $($geoInfo.city)"
            Write-Host " ISP: $($geoInfo.isp)"
            Write-Host " Timezone: $($geoInfo.timezone)"
        }
    } catch {
        Write-Host " Could not retrieve geographic information"
    }
} else {
    Write-Host " Could not retrieve public IP address"
}

Write-Host "`nActive Network Adapters:"
# Get all network adapters with connection status 2 (connected/active)
Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | ForEach-Object {
    # Determine adapter type based on name (Wi-Fi or Ethernet)
    $type = if ($_.Name -match 'Wireless|Wi[- ]?Fi') { 'Wi-Fi' } else { 'Ethernet' }
    
    # Convert link speed from bps to Mbps for readability
    if ($_.Speed) {
        $speedMbps = [math]::Round($_.Speed / 1000000, 1)
        $speedText = "$speedMbps Mbps"
    } else {
        $speedText = "Not Available"
    }
    
    # Get adapter configuration to retrieve IP and DNS information
    $adapterIndex = $_.Index
    $adapterConfig = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $adapterIndex }
    
    # Initialize variables for IP and DNS information
    $ipAddress = " No IP Address"
    $dnsServers = " No DNS Servers"
    
    if ($adapterConfig) {
        # Extract IPv4 address (filter out IPv6 addresses)
        if ($adapterConfig.IPAddress) {
            $ipv4Address = $adapterConfig.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
            if ($ipv4Address) {
                $ipAddress = $ipv4Address
            }
        }
        
        # Extract IPv4 DNS servers (filter out IPv6 addresses)
        if ($adapterConfig.DNSServerSearchOrder -and $adapterConfig.DNSServerSearchOrder.Count -gt 0) {
            $ipv4DnsServers = $adapterConfig.DNSServerSearchOrder | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
            if ($ipv4DnsServers) {
                $dnsServers = $ipv4DnsServers -join ", "
            }
        }
    }
    
    # Display adapter information with formatted output
    Write-Host " Adapter Name: $($_.Name)"
    Write-Host "  Type: $type"
    Write-Host "  Speed: $speedText"
    Write-Host "  DNS Servers: $dnsServers"
    Write-Host "  Local IP Address (LAN): $ipAddress"
    Write-Host "  MAC Address: $($_.MACAddress)"
    Write-Host ""  # Empty line for readability between adapters
}

# Check and display IPv6 status
Write-Host "IPv6 Status:"
# Get IPv6 addresses that are not link-local, loopback, or specific reserved ranges
$ipv6Addresses = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
    Where-Object {
        # Exclude link-local addresses (fe80::/10)
        $_.IPAddress -notlike 'fe80*' -and 
        # Exclude loopback address (::1)
        $_.IPAddress -notlike '::1' -and
        # Filter by prefix origin to get only certain types of addresses
        $_.PrefixOrigin -ne 'WellKnown' -and
        $_.PrefixOrigin -ne 'RouterAdvertisement' -and
        $_.PrefixOrigin -ne 'Dhcp' -and
        $_.PrefixOrigin -ne 'Manual'
    } |
    Where-Object {
        # Exclude specific IPv6 address ranges
        $_.IPAddress -notmatch '^2001:0:' -and  # Teredo tunneling
        $_.IPAddress -notmatch '^2002:' -and     # 6to4 tunneling
        $_.IPAddress -notmatch '^::ffff:'        # IPv4-mapped IPv6 addresses
    }

if ($ipv6Addresses) {
    Write-Host " Active"
    # Display first 3 IPv6 addresses with their interface names
    $ipv6Addresses | Select-Object -First 3 | ForEach-Object {
        Write-Host "   $($_.IPAddress) [$($_.InterfaceAlias)]"
    }
    # Indicate if there are more addresses not shown
    if ($ipv6Addresses.Count -gt 3) {
        Write-Host " $($ipv6Addresses.Count - 3) more"
    }
} else {
    Write-Host " Inactive or not configured"
}

Write-Host "`nActive TCP Connections:"
# Get all TCP connections that are currently established (active data transfer)
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
Write-Host "`nTCP Port".PadRight(20) "Process"
Write-Host "--------".PadRight(19) "--------"

# Get all TCP connections in Listen state (open ports waiting for connections)
$tcp = Get-NetTCPConnection -State Listen |
       Select-Object LocalPort, OwningProcess -Unique |  # Remove duplicates
       Sort-Object LocalPort  # Sort by port number

# Display each listening TCP port with its associated process
$tcp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(18)) $($procName -or 'Unknown')"
}

# Display UDP ports that are open (UDP is connectionless, so no "listening" state)
Write-Host "`nUDP Port".PadRight(20) "Process"
Write-Host "--------".PadRight(19) "--------"

# Get all UDP endpoints (open UDP ports)
$udp = Get-NetUDPEndpoint |
       Select-Object LocalPort, OwningProcess -Unique |  # Remove duplicates
       Sort-Object LocalPort  # Sort by port number

# Display each open UDP port with its associated process
$udp | ForEach-Object {
    $procName = ($procs | Where-Object Id -eq $_.OwningProcess).ProcessName
    Write-Host " $($_.LocalPort.ToString().PadRight(18)) $($procName -or 'Unknown')"
}

# Display Windows Firewall status for all profiles
Write-Host "`nFirewall Status:"
# Get firewall settings for Domain, Private, and Public profiles
Get-NetFirewallProfile | ForEach-Object {
    $status = if ($_.Enabled) { 'ENABLED' } else { 'DISABLED' }
    Write-Host " $($_.Name): $status"
}

# Display VPN connection information
Write-Host "`nVPN Connections:"
# Get all VPN connections (including those for all users)
$vpnConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
if ($vpnConnections) {
    # Display VPN connections in a formatted table
    $vpnConnections | Format-Table Name, ServerAddress, ConnectionStatus -AutoSize
} else {
    Write-Host " No VPN connections"
}

# Display system proxy configuration
Write-Host "`nProxy Status:"
# Use netsh command to check WinHTTP proxy settings
$proxy = netsh winhttp show proxy 2>$null
if ($proxy -match 'Direct access') {
    Write-Host " No proxy configured"
} else {
    # Parse and display proxy configuration details
    $proxyLines = $proxy -split "`n" | Where-Object { $_ -match ':' }
    foreach ($line in $proxyLines) {
        Write-Host " $($line.Trim())"
    }
}

# Scan and display available Wi-Fi networks
Write-Host "`nAvailable Wi-Fi Networks"

# Define helper function to display network information in a formatted way
function DisplayNetworkInfo {
    param([string]$ssid, [hashtable]$info)
    Write-Host "`n SSID/Network Name: $ssid"
    if ($info["Signal"]) { Write-Host "  Signal Strength: $($info["Signal"])%" }
    if ($info["Channel"]) { Write-Host "  Channel: $($info["Channel"])" }
    if ($info["RadioType"]) { Write-Host "  Radio Type: $($info["RadioType"])" }
    if ($info["Authentication"]) { Write-Host "  Authentication: $($info["Authentication"])" }
    if ($info["Cipher"]) { Write-Host "  Cipher: $($info["Cipher"])" }
}

# Scan for available Wi-Fi networks with BSSID (Access Point) details
$availableNetworks = netsh wlan show networks mode=bssid 2>$null
if ($availableNetworks) {
    $currentSSID = ""
    $networkInfo = @{}
    
    # Parse the output line by line
    foreach ($line in $availableNetworks) {
        # Detect when a new SSID section starts
        if ($line -match "SSID (\d+) : (.+)") {
            # Display previous network info if exists
            if ($currentSSID -ne "") {
                DisplayNetworkInfo -ssid $currentSSID -info $networkInfo
            }
            $currentSSID = $matches[2].Trim()
            $networkInfo = @{}  # Reset info for new network
        }
        elseif ($currentSSID -ne "") {
            # Extract various network properties using regex patterns
            if ($line -match "Signal\s*:\s*(\d+)%") { $networkInfo["Signal"] = $matches[1] }
            elseif ($line -match "Channel\s*:\s*(\d+)") { $networkInfo["Channel"] = $matches[1] }
            elseif ($line -match "Radio type\s*:\s*(.+)") { $networkInfo["RadioType"] = $matches[1].Trim() }
            elseif ($line -match "Authentication\s*:\s*(.+)") { $networkInfo["Authentication"] = $matches[1].Trim() }
            elseif ($line -match "Cipher\s*:\s*(.+)") { $networkInfo["Cipher"] = $matches[1].Trim() }
        }
    }
    
    # Display the last network's information
    if ($currentSSID -ne "") {
        DisplayNetworkInfo -ssid $currentSSID -info $networkInfo
    }
} else {
    Write-Host " No Wi-Fi networks available or no Wi-Fi adapter found"
}

# Display shared folders (SMB shares) on the system
Write-Host "`nShared folders:"
# Get all SMB (Server Message Block) shares
Get-SmbShare | ForEach-Object {
    Write-Host " Share: $($_.Name) | Path: $($_.Path) | Description: $($_.Description -or 'None')"
}