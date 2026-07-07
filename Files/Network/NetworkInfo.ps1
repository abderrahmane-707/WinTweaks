param (
    [Parameter(Position = 0)]
    [string]$LogPath,

    [string]$ExportPath
)

. "$PSScriptRoot\..\Common\Logger.ps1"

# Begin transcript if an export path is provided.
if ($ExportPath) {
    Start-Transcript -Path $ExportPath -Append -ErrorAction SilentlyContinue | Out-Null
}

# Helper to display Wi-Fi network details consistently.
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

# Pre-cache process names for rapid lookup during port enumeration.
$ProcessMap = @{}
Get-Process | ForEach-Object { $ProcessMap[$_.Id] = $_.ProcessName }

# --- Data Collection ---

# Current user context
Write-Log "Username: $env:USERNAME"
Write-Log "Domain: $env:USERDOMAIN"

# Basic internet connectivity test via the default gateway (avoids false negatives in firewalled environments)
Write-Log "`nConnection tests:"
$defaultGateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
$pingTarget = if ($defaultGateway) { $defaultGateway } else { "8.8.8.8" }
if (Test-Connection -ComputerName $pingTarget -Count 3 -Quiet -ErrorAction SilentlyContinue) {
    Write-Log " Connected"
} else {
    Write-Log " Disconnected"
}

# Default gateway
Write-Log "`nDefault Gateway Address:"
$gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop
if ($gateway) {
    Write-Log " $gateway"
} else {
    Write-Log " Not found"
}

# Public IP Address & GeoIP lookup
Write-Log "`nPublic IP Address (WAN):"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$publicIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -ErrorAction SilentlyContinue
if ($publicIP -and $publicIP.ip) {
    Write-Log " IP Address: $($publicIP.ip)"
    try {
        $geoInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($publicIP.ip)" -ErrorAction SilentlyContinue
        if ($geoInfo) {
            Write-Log " Country: $($geoInfo.country)"
            Write-Log " City: $($geoInfo.city)"
            Write-Log " ISP: $($geoInfo.isp)"
            Write-Log " Timezone: $($geoInfo.timezone)"
        }
    } catch {
        Write-Log " Could not retrieve geographic information"
    }
} else {
    Write-Log " Could not retrieve public IP address"
}

# Active Network Adapters
Write-Log "`nActive Network Adapters:"
Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | ForEach-Object {
    $type = if ($_.Name -match 'Wireless|Wi[- ]?Fi') { 'Wi-Fi' } else { 'Ethernet' }
    $speedText = if ($_.Speed) { "$([math]::Round($_.Speed / 1000000, 1)) Mbps" } else { "Not Available" }

    $adapterIndex = $_.Index
    $adapterConfig = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $adapterIndex }

    $ipAddress = " No IP Address"
    $dnsServers = " No DNS Servers"

    if ($adapterConfig) {
        if ($adapterConfig.IPAddress) {
            $ipv4Address = $adapterConfig.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
            if ($ipv4Address) { $ipAddress = $ipv4Address }
        }
        if ($adapterConfig.DNSServerSearchOrder -and $adapterConfig.DNSServerSearchOrder.Count -gt 0) {
            $ipv4DnsServers = $adapterConfig.DNSServerSearchOrder | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
            if ($ipv4DnsServers) { $dnsServers = $ipv4DnsServers -join ", " }
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

# IPv6 Status
Write-Log "IPv6 Status:"
$ipv6Addresses = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object {
    $_.IPAddress -notlike 'fe80*' -and
    $_.IPAddress -notlike '::1' -and
    $_.PrefixOrigin -notin @('WellKnown', 'RouterAdvertisement', 'Dhcp', 'Manual') -and
    $_.IPAddress -notmatch '^2001:0:|^2002:|^::ffff:'
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
    Write-Log " Local Address".PadRight(25) "Remote Address".PadRight(25) "Process"
    Write-Log " -------------".PadRight(25) "--------------".PadRight(25) "-------"

    foreach ($conn in $connections | Sort-Object LocalPort) {
        $processName = $ProcessMap[$conn.OwningProcess]
        if (-not $processName) { $processName = "N/A" }

        $local = "$($conn.LocalAddress):$($conn.LocalPort)"
        $remote = "$($conn.RemoteAddress):$($conn.RemotePort)"
        Write-Log " $($local.PadRight(25)) $($remote.PadRight(25)) $processName"
    }
} else {
    Write-Log " No established connections found"
}

# Listening TCP Ports
Write-Log "`nTCP Port".PadRight(20) "Process"
Write-Log "--------".PadRight(19) "--------"
Get-NetTCPConnection -State Listen | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort | ForEach-Object {
    $procName = $ProcessMap[$_.OwningProcess]
    Write-Log " $($_.LocalPort.ToString().PadRight(18)) $($procName -or 'Unknown')"
}

# Open UDP Ports
Write-Log "`nUDP Port".PadRight(20) "Process"
Write-Log "--------".PadRight(19) "--------"
Get-NetUDPEndpoint | Select-Object LocalPort, OwningProcess -Unique | Sort-Object LocalPort | ForEach-Object {
    $procName = $ProcessMap[$_.OwningProcess]
    Write-Log " $($_.LocalPort.ToString().PadRight(18)) $($procName -or 'Unknown')"
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

# Finalize transcript if it was started
if ($ExportPath) {
    Stop-Transcript | Out-Null
    Write-Log "`nReport also saved to: $ExportPath"
}