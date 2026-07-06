# Check for working IPv6 connectivity
$hasGlobalIPv6 = $false

$ipv6Test = Test-Connection "2606:4700:4700::1111" -Count 1 -ErrorAction SilentlyContinue
if ($ipv6Test) {
    $hasGlobalIPv6 = $true
}

# DNS servers to benchmark
$testServers = @(
    @{Name="Google IPv4"; Address="8.8.8.8"; Type="IPv4"},
    @{Name="Cloudflare IPv4"; Address="1.1.1.1"; Type="IPv4"},
    @{Name="Cloudflare Family IPv4"; Address="1.1.1.3"; Type="IPv4"},
    @{Name="AdGuard IPv4"; Address="94.140.14.15"; Type="IPv4"},
    @{Name="CleanBrowsing Family IPv4"; Address="185.228.168.168"; Type="IPv4"},
    @{Name="Quad9 Security IPv4"; Address="9.9.9.9"; Type="IPv4"},
    @{Name="OpenDNS IPv4"; Address="208.67.222.222"; Type="IPv4"}
)

# Include IPv6 DNS servers when available
if ($hasGlobalIPv6) {
    Write-Host "IPv6 Connectivity Detected. Adding IPv6 servers to the test.`n"

    $testServers += @(
        @{Name="Google IPv6"; Address="2001:4860:4860::8888"; Type="IPv6"},
        @{Name="Cloudflare IPv6"; Address="2606:4700:4700::1111"; Type="IPv6"},
        @{Name="Cloudflare Family IPv6"; Address="2606:4700:4700::1113"; Type="IPv6"},
        @{Name="AdGuard IPv6"; Address="2a10:50c0::bad:ff"; Type="IPv6"},
        @{Name="CleanBrowsing Family IPv6"; Address="2a0d:2a00:1::"; Type="IPv6"},
        @{Name="Quad9 Security IPv6"; Address="2620:fe::fe"; Type="IPv6"},
        @{Name="OpenDNS IPv6"; Address="2620:119:35::35"; Type="IPv6"}
    )
}
else {
    Write-Host "No IPv6 Connectivity Detected`n"
}

# Display benchmark results
Write-Host "Testing connection on DNS servers:`n"

$formatString = "{0,-28} {1,-22} {2,-6} {3,-8} {4,-10} {5,-10} {6,-10}"

Write-Host ($formatString -f "ServerName", "IPAddress", "Type", "Status", "Avg (ms)", "Min (ms)", "Max (ms)")
Write-Host ($formatString -f "----------", "---------", "----", "------", "--------", "--------", "--------")

# Measure latency for each DNS server
foreach ($server in $testServers) {

    $status = "Failed"
    $avg = "N/A"
    $min = "N/A"
    $max = "N/A"

    try {
        $ping = Test-Connection -ComputerName $server.Address -Count 3 -ErrorAction Stop

        if ($ping) {
            $status = "Online"
            $avg = [math]::Round(($ping | Measure-Object ResponseTime -Average).Average, 2)
            $min = [math]::Round(($ping | Measure-Object ResponseTime -Minimum).Minimum, 2)
            $max = [math]::Round(($ping | Measure-Object ResponseTime -Maximum).Maximum, 2)
        }
    }
    catch {
    }

    Write-Host ($formatString -f $server.Name, $server.Address, $server.Type, $status, $avg, $min, $max)

    Start-Sleep -Seconds 1
}

# Verify DNS name resolution
Write-Host "`nDNS Resolution Test:"

$hosts = @(
    "google.com",
    "cloudflare.com",
    "microsoft.com",
    "facebook.com"
)

foreach ($h in $hosts) {
    $result = Resolve-DnsName -Name $h -ErrorAction SilentlyContinue

    if ($result) {
        Write-Host "  $h : Working"
    }
    else {
        Write-Host "  $h : Failed"
    }
}