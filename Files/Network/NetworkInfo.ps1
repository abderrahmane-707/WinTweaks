Write-Host "Username: $env:USERNAME"
Write-Host "Domain: $env:USERDOMAIN"

Write-Host "`nConnection tests:"
$connected = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($connected) {
    Write-Host " Connected"
}
else {
    Write-Host " Disconnected"
}

Write-Host "`nDefault Gateway Address:"
$gateway = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop
if ($gateway) {
    Write-Host " $gateway"
} else {
    Write-Host " Not found"
}

Write-Host "`nPublic IP Address (WAN):"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$publicIP = $null
$publicIP = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -ErrorAction SilentlyContinue
if ($publicIP -and $publicIP.ip) {
    Write-Host " IP Address: $($publicIP.ip)"
    try {
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
Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 } | ForEach-Object {
    $type = if ($_.Name -match 'Wireless|Wi[- ]?Fi') { 'Wi-Fi' } else { 'Ethernet' }
    if ($_.Speed) {
        $speedMbps = [math]::Round($_.Speed / 1000000, 1)
        $speedText = "$speedMbps Mbps"
    } else {
        $speedText = "Not Available"
    }
    $adapterIndex = $_.Index
    $adapterConfig = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.Index -eq $adapterIndex }
    $ipAddress = " No IP Address"
    $dnsServers = " No DNS Servers"
    if ($adapterConfig) {
        if ($adapterConfig.IPAddress) {
            $ipv4Address = $adapterConfig.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1
            if ($ipv4Address) {
                $ipAddress = $ipv4Address
            }
        }
        if ($adapterConfig.DNSServerSearchOrder -and $adapterConfig.DNSServerSearchOrder.Count -gt 0) {
            $ipv4DnsServers = $adapterConfig.DNSServerSearchOrder | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
            if ($ipv4DnsServers) {
                $dnsServers = $ipv4DnsServers -join ", "
            }
        }
    }
    Write-Host " Adapter Name: $($_.Name)"
    Write-Host "  Type: $type"
    Write-Host "  Speed: $speedText"
    Write-Host "  DNS Servers: $dnsServers"
    Write-Host "  Local IP Address (LAN): $ipAddress"
    Write-Host "  MAC Address: $($_.MACAddress)"
    Write-Host ""
}

Write-Host "IPv6 Status:"
$ipv6Addresses = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike 'fe80*' -and $_.IPAddress -notlike '::1' -and
        $_.PrefixOrigin -ne 'WellKnown' -and
        $_.PrefixOrigin -ne 'RouterAdvertisement' -and
        $_.PrefixOrigin -ne 'Dhcp' -and
        $_.PrefixOrigin -ne 'Manual'
    } |
    Where-Object {
        $_.IPAddress -notmatch '^2001:0:' -and
        $_.IPAddress -notmatch '^2002:' -and
        $_.IPAddress -notmatch '^::ffff:' 
    }
if ($ipv6Addresses) {
    Write-Host "  Active"
    $ipv6Addresses | Select-Object -First 3 | ForEach-Object {
        Write-Host "   $($_.IPAddress) [$($_.InterfaceAlias)]"
    }
    if ($ipv6Addresses.Count -gt 3) {
        Write-Host "  ... and $($ipv6Addresses.Count - 3) more"
    }
} else {
    Write-Host " Inactive or not configured"
}

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

Write-Host "`nVPN Connections:"
$vpnConnections = Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue
if ($vpnConnections) {
    $vpnConnections | Format-Table Name, ServerAddress, ConnectionStatus -AutoSize
} else {
    Write-Host "  No VPN connections"
}

Write-Host "`nProxy Status:"
$proxy = netsh winhttp show proxy 2>$null
if ($proxy -match 'Direct access') {
    Write-Host "  No proxy configured"
} else {
    $proxyLines = $proxy -split "`n" | Where-Object { $_ -match ':' }
    foreach ($line in $proxyLines) {
        Write-Host "  $($line.Trim())"
    }
}

Write-Host "`nAvailable Wi-Fi Networks"
function DisplayNetworkInfo {
    param([string]$ssid, [hashtable]$info)
    Write-Host "`n SSID/Network Name: $ssid"
    if ($info["Signal"]) { Write-Host "  Signal Strength: $($info["Signal"])%" }
    if ($info["Channel"]) { Write-Host "  Channel: $($info["Channel"])" }
    if ($info["RadioType"]) { Write-Host "  Radio Type: $($info["RadioType"])" }
    if ($info["Authentication"]) { Write-Host "  Authentication: $($info["Authentication"])" }
    if ($info["Cipher"]) { Write-Host "  Cipher: $($info["Cipher"])" }
}
$availableNetworks = netsh wlan show networks mode=bssid 2>$null
if ($availableNetworks) {
    $currentSSID = ""
    $networkInfo = @{}
    foreach ($line in $availableNetworks) {
        if ($line -match "SSID (\d+) : (.+)") {
            if ($currentSSID -ne "") {
                DisplayNetworkInfo -ssid $currentSSID -info $networkInfo
            }
            $currentSSID = $matches[2].Trim()
            $networkInfo = @{}
        }
        elseif ($currentSSID -ne "") {
            if ($line -match "Signal\s*:\s*(\d+)%") { $networkInfo["Signal"] = $matches[1] }
            elseif ($line -match "Channel\s*:\s*(\d+)") { $networkInfo["Channel"] = $matches[1] }
            elseif ($line -match "Radio type\s*:\s*(.+)") { $networkInfo["RadioType"] = $matches[1].Trim() }
            elseif ($line -match "Authentication\s*:\s*(.+)") { $networkInfo["Authentication"] = $matches[1].Trim() }
            elseif ($line -match "Cipher\s*:\s*(.+)") { $networkInfo["Cipher"] = $matches[1].Trim() }
        }
    }
    if ($currentSSID -ne "") {
        DisplayNetworkInfo -ssid $currentSSID -info $networkInfo
    }
} else {
    Write-Host " No Wi-Fi networks available or no Wi-Fi adapter found"
}

Write-Host "`nShared folders:"
Get-SmbShare | ForEach-Object {
    Write-Host " Share: $($_.Name) | Path: $($_.Path) | Description: $($_.Description -or 'None')"
}