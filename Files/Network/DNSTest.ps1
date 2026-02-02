Write-Host "Testing connection on DNS servers:"

# Check if system has global IPv6 connectivity by testing Cloudflare's IPv6 DNS
if (-not $hasGlobalIPv6) {
    $ipv6Test = Test-Connection "2606:4700:4700::1111" -Count 1 -ErrorAction SilentlyContinue
    if ($ipv6Test) {
        $hasGlobalIPv6 = $true
    }
}

# Define array of IPv4 DNS servers to test with their properties
$testServers = @(
    @{Name="Google IPv4"; Address="8.8.8.8"; Type="IPv4"},
    @{Name="Cloudflare IPv4"; Address="1.1.1.1"; Type="IPv4"},
    @{Name="Cloudflare Family IPv4 "; Address="1.1.1.3"; Type="IPv4"},
    @{Name="AdGuard IPv4"; Address="94.140.14.15"; Type="IPv4"},
    @{Name="CleanBrowsing Family IPv4"; Address="185.228.168.168"; Type="IPv4"},
    @{Name="Quad9 Security IPv4"; Address="9.9.9.9"; Type="IPv4"},
    @{Name="OpenDNS IPv4"; Address="208.67.222.222"; Type="IPv4"}
)

# If system has IPv6 connectivity, add IPv6 DNS servers to the test list
if ($hasGlobalIPv6) {
    $testServers += @(
        @{Name="Google IPv6"; Address="2001:4860:4860::8888"; Type="IPv6"},
        @{Name="Cloudflare IPv6"; Address="2606:4700:4700::1111"; Type="IPv6"},
        @{Name="Cloudflare Family IPv6 "; Address="2606:4700:4700::1113"; Type="IPv6"},
        @{Name="AdGuard IPv6"; Address="2a10:50c0::bad:ff"; Type="IPv6"},
        @{Name="CleanBrowsing Family IPv6"; Address="2a0d:2a00:1::"; Type="IPv6"},
        @{Name="Quad9 Security IPv6"; Address="2620:fe::fe"; Type="IPv6"},
        @{Name="OpenDNS IPv6"; Address="2620:fe::fe"; Type="IPv6"}
    )
}

# Initialize array to store test results (though not currently used for storage)
$results = @()

# Loop through each DNS server and perform connectivity test
foreach ($server in $testServers) {
    # Display server name and address without newline (will show results on same line)
    Write-Host " $($server.Name) ($($server.Address)):" -NoNewline
    
    try {
        # Send 3 ICMP ping requests to the DNS server
        $ping = Test-Connection -ComputerName $server.Address -Count 3 -ErrorAction Stop
        
        # If ping was successful, calculate latency statistics
        if ($ping) {
            # Calculate average, minimum, and maximum response times from the 3 pings
            $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
            $minLatency = ($ping | Measure-Object -Property ResponseTime -Minimum).Minimum
            $maxLatency = ($ping | Measure-Object -Property ResponseTime -Maximum).Maximum
            
            # Display formatted latency statistics with 2 decimal places
            Write-Host "Avg: $([math]::Round($avgLatency, 2)) ms | Min: $([math]::Round($minLatency, 2)) ms | Max: $([math]::Round($maxLatency, 2)) ms"
        }
    }
    catch {
        # Handle connection failures - display error message
        Write-Host " Failed"
        Write-Host " $($_.Exception.Message)"
    }
    
    # Pause for 1 second between tests to avoid overwhelming network/remote servers
    Start-Sleep -Seconds 1
}

# Begin DNS resolution test section
Write-Host "`nDNS Resolution Test:"

# Define list of popular domains to test DNS resolution functionality
$hosts = @("google.com", "cloudflare.com", "microsoft.com", "facebook.com")

# Test each domain name resolution
foreach ($h in $hosts) {
    # Attempt to resolve domain name to IP address(es)
    $result = Resolve-DnsName $h -ErrorAction SilentlyContinue
    
    # Check if resolution was successful
    if ($result) {
        Write-Host " $h  Working"
    } else {
        Write-Host " $h  Failed"
    }
}