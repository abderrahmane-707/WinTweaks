param (
    [Parameter(Position = 0)]
    [string]$LogPath,

    [string]$ExportPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Helper to display Wi-Fi network details consistently
function DisplayNetworkInfo {
    param (
        [string]$ssid,
        [hashtable]$info
    )
    Write-Log "`n SSID/Network Name: $ssid"
    if ($info["Signal"])        { Write-Log "  Signal Strength: $($info["Signal"])%" }
    if ($info["Channel"])       { Write-Log "  Channel: $($info["Channel"])" }
    if ($info["RadioType"])     { Write-Log "  Radio Type: $($info["RadioType"])" }
    if ($info["Authentication"]){ Write-Log "  Authentication: $($info["Authentication"])" }
    if ($info["Cipher"])        { Write-Log "  Cipher: $($info["Cipher"])" }
}

# Pre-cache process names for rapid lookup during port enumeration
$ProcessMap = @{}
Get-Process | ForEach-Object { $ProcessMap[[string]$_.Id] = $_.ProcessName }
$ProcessMap["0"] = "System Idle Process"
$ProcessMap["4"] = "System"

# Current user context
Write-Log "Username: $env:USERNAME"
Write-Log "Domain: $env:USERDOMAIN"

$defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
    Sort-Object RouteMetric |
    Select-Object -First 1

$defaultGateway = $defaultRoute.NextHop

# Basic internet connectivity test via the default gateway
Write-Log "`nConnection tests:"
$pingTarget = if ($defaultGateway) { $defaultGateway } else { "8.8.8.8" }
$isConnected = Test-Connection -ComputerName $pingTarget -Count 3 -Quiet -ErrorAction SilentlyContinue
if ($isConnected) {
    Write-Log " Connected"
} else {
    Write-Log " Disconnected"
}

# Default gateway
Write-Log "`nDefault Gateway Address:"
if ($defaultGateway) {
    Write-Log " $defaultGateway"
} else {
    Write-Log " Not found"
}

# Public IP Address & GeoIP lookup
Write-Log "`nPublic IP Address (WAN):"
if (-not $isConnected) {
    Write-Log " Skipped (no internet connectivity detected)"
}
else {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $publicIP = $null
    try {
        $publicIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5 -ErrorAction Stop
    }
    catch {
        Write-Log " Could not retrieve public IP address: $($_.Exception.Message)"
    }

    if ($publicIP -and $publicIP.ip) {
        Write-Log " IP Address: $($publicIP.ip)"
        try {
            $geoInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($publicIP.ip)" -TimeoutSec 5 -ErrorAction Stop
            if ($geoInfo) {
                Write-Log " Country: $($geoInfo.country)"
                Write-Log " City: $($geoInfo.city)"
                Write-Log " ISP: $($geoInfo.isp)"
                Write-Log " Timezone: $($geoInfo.timezone)"
            }
        } catch {
            Write-Log " Could not retrieve geographic information: $($_.Exception.Message)"
        }
    }
}

# Active Network Adapters
Write-Log "`nActive Network Adapters:"

$allAdapterConfigs = Get-CimInstance Win32_NetworkAdapterConfiguration

Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | ForEach-Object {
    $type = if ($_.Name -match 'Wireless|Wi[- ]?Fi') { 'Wi-Fi' } else { 'Ethernet' }
    $speedText = if ($_.Speed) { "$([math]::Round($_.Speed / 1000000, 1)) Mbps" } else { "Not Available" }

    $adapterIndex = $_.Index
    $adapterConfig = $allAdapterConfigs | Where-Object { $_.Index -eq $adapterIndex }

    $ipAddress = " No IP Address"
    $dnsServers = " No DNS Servers"

    if ($adapterConfig) {
        if ($adapterConfig.IPAddress) {
            $ipv4Address = $adapterConfig.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
            if ($ipv4Address) {
                $ipAddress = $ipv4Address
            }
            else {
                # Display the IPv6 address as a fallback if no IPv4 address is available
                $ipv6Address = $adapterConfig.IPAddress | Where-Object { $_ -match ':' } | Select-Object -First 1
                if ($ipv6Address) { $ipAddress = "$ipv6Address (IPv6)" }
            }
        }
        if ($adapterConfig.DNSServerSearchOrder -and $adapterConfig.DNSServerSearchOrder.Count -gt 0) {
            $ipv4DnsServers = $adapterConfig.DNSServerSearchOrder | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
            if ($ipv4DnsServers) {
                $dnsServers = $ipv4DnsServers -join ", "
            }
            else {
                $ipv6DnsServers = $adapterConfig.DNSServerSearchOrder | Where-Object { $_ -match ':' }
                if ($ipv6DnsServers) { $dnsServers = ($ipv6DnsServers -join ", ") + " (IPv6)" }
            }
        }
    }

    Write-Log " Adapter Name: $($_.Name)"
    Write-Log "  Type: $type"
    Write-Log "  Speed: $speedText"
    Write-Log "  DNS Servers: $dnsServers"
    Write-Log "  Local IP Address (LAN): $ipAddress"
    Write-Log "  MAC Address: $($_.MACAddress)"
    Write-Log ""
}

# Check and display IPv6 status
Write-Log "IPv6 Status:"
$ipv6Addresses = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike 'fe80*' -and
        $_.IPAddress -notlike '::1' -and
        # Exclude only router-advertised/local addresses, while retaining actual DHCP and manual addresses
        $_.PrefixOrigin -notin @('WellKnown', 'RouterAdvertisement')
    } |
    Where-Object {
        $_.IPAddress -notmatch '^2001:0:' -and
        $_.IPAddress -notmatch '^2002:' -and
        $_.IPAddress -notmatch '^::ffff:'
    }

if ($ipv6Addresses) {
    Write-Log " Active"
    $ipv6Addresses | Select-Object -First 3 | ForEach-Object {
        Write-Log "   $($_.IPAddress) [$($_.InterfaceAlias)]"
    }
    if ($ipv6Addresses.Count -gt 3) { Write-Log " $($ipv6Addresses.Count - 3) more" }
} else {
    Write-Log " Inactive or not configured"
}

# Active TCP Connections
Write-Log "`nActive TCP Connections:"
$connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
if ($connections) {
    $tcpTable = $connections | Sort-Object LocalPort | ForEach-Object {
        $processName = $ProcessMap[[string]$_.OwningProcess]
        if (-not $processName) { $processName = "N/A" }

        [PSCustomObject]@{
            "Local Address"  = "$($_.LocalAddress):$($_.LocalPort)"
            "Remote Address" = "$($_.RemoteAddress):$($_.RemotePort)"
            "Process"        = $processName
        }
    } | Format-Table -AutoSize | Out-String

    Write-Log $tcpTable
} else {
    Write-Log " No established connections found"
}

# Listening TCP & UDP Ports
Write-Log "`nListening Ports (TCP/UDP):"

$listeningPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort
$udpPorts = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort

$combinedPorts = @()

if ($listeningPorts) {
    $combinedPorts += $listeningPorts | ForEach-Object {
        $procName = $ProcessMap[[string]$_.OwningProcess]
        [PSCustomObject]@{
            "Protocol" = "TCP"
            "Port"     = $_.LocalPort
            "Process"  = if ($procName) { $procName } else { 'Unknown' }
        }
    }
}

if ($udpPorts) {
    $combinedPorts += $udpPorts | ForEach-Object {
        $procName = $ProcessMap[[string]$_.OwningProcess]
        [PSCustomObject]@{
            "Protocol" = "UDP"
            "Port"     = $_.LocalPort
            "Process"  = if ($procName) { $procName } else { 'Unknown' }
        }
    }
}

if ($combinedPorts.Count -gt 0) {
    $portsTable = $combinedPorts | Sort-Object Protocol, Port | Format-Table -AutoSize | Out-String
    Write-Log $portsTable
} else {
    Write-Log " No listening TCP or UDP ports found"
}

# Firewall Status
Write-Log "`nFirewall Status:"
Get-NetFirewallProfile | ForEach-Object {
    $status = if ($_.Enabled) { 'ENABLED' } else { 'DISABLED' }
    Write-Log " $($_.Name): $status"
}

# VPN Connections
Write-Log "`nVPN Connections:"
$vpnConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
if ($vpnConnections) {
    $vpnTable = $vpnConnections | Format-Table Name, ServerAddress, ConnectionStatus -AutoSize | Out-String
    Write-Log $vpnTable
} else {
    Write-Log " No VPN connections"
}

# Proxy Status
Write-Log "`nProxy Status:"
$proxy = netsh winhttp show proxy 2>$null
if ($proxy -match 'Direct access') {
    Write-Log " No proxy configured"
} else {
    $proxyLines = $proxy -split "`n" | Where-Object { $_ -match ':' }
    foreach ($line in $proxyLines) { Write-Log " $($line.Trim())" }
}

# Shared folders (SMB)
Write-Log "`nShared folders:"
try {
    Get-SmbShare -ErrorAction Stop | ForEach-Object {
        $description = if ($_.Description) { $_.Description } else { 'None' }
        Write-Log " Share: $($_.Name) | Path: $($_.Path) | Description: $description"
    }
} catch {
    Write-Log " Could not read SMB shares"
}

# Wi-Fi Networks Scan
Write-Log "`nAvailable Wi-Fi Networks"
$availableNetworks = netsh wlan show networks mode=bssid 2>$null
if ($availableNetworks) {
    $currentSSID = ""
    $networkInfo = @{}

    foreach ($line in $availableNetworks) {
        if ($line -match "SSID (\d+) : (.+)") {
            if ($currentSSID -ne "") { DisplayNetworkInfo -ssid $currentSSID -info $networkInfo }
            $currentSSID = $matches[2].Trim()
            $networkInfo = @{}
        } elseif ($currentSSID -ne "") {
            if ($line -match "Signal\s*:\s*(\d+)%")          { $networkInfo["Signal"] = $matches[1] }
            elseif ($line -match "Channel\s*:\s*(\d+)")       { $networkInfo["Channel"] = $matches[1] }
            elseif ($line -match "Radio type\s*:\s*(.+)")     { $networkInfo["RadioType"] = $matches[1].Trim() }
            elseif ($line -match "Authentication\s*:\s*(.+)") { $networkInfo["Authentication"] = $matches[1].Trim() }
            elseif ($line -match "Cipher\s*:\s*(.+)")         { $networkInfo["Cipher"] = $matches[1].Trim() }
        }
    }
    if ($currentSSID -ne "") { DisplayNetworkInfo -ssid $currentSSID -info $networkInfo }
} else {
    Write-Log " No Wi-Fi networks available or no Wi-Fi adapter found"
}
