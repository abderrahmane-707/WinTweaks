Write-Host "Testing connection on DNS servers:"
if (-not $hasGlobalIPv6) {
    $ipv6Test = Test-Connection "2606:4700:4700::1111" -Count 1 -ErrorAction SilentlyContinue
    if ($ipv6Test) {
        $hasGlobalIPv6 = $true
    }
}

$testServers = @(
    @{Name="Google IPv4"; Address="8.8.8.8"; Type="IPv4"},
    @{Name="Cloudflare IPv4"; Address="1.1.1.1"; Type="IPv4"},
    @{Name="Cloudflare Family IPv4 "; Address="1.1.1.3"; Type="IPv4"},
    @{Name="AdGuard IPv4"; Address="94.140.14.15"; Type="IPv4"},
    @{Name="CleanBrowsing Family IPv4"; Address="185.228.168.168"; Type="IPv4"},
    @{Name="Quad9 Security IPv4"; Address="9.9.9.9"; Type="IPv4"},
	@{Name="OpenDNS IPv4"; Address="208.67.222.222"; Type="IPv4"}
)

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

$results = @()
foreach ($server in $testServers) {
    Write-Host " $($server.Name) ($($server.Address)):" -NoNewline
try {
    $ping = Test-Connection -ComputerName $server.Address -Count 3 -ErrorAction Stop
    if ($ping) {
        $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
        $minLatency = ($ping | Measure-Object -Property ResponseTime -Minimum).Minimum
        $maxLatency = ($ping | Measure-Object -Property ResponseTime -Maximum).Maximum

        Write-Host "Avg: $([math]::Round($avgLatency, 2)) ms | Min: $([math]::Round($minLatency, 2)) ms | Max: $([math]::Round($maxLatency, 2)) ms"
    }
}
    catch {
        Write-Host " Failed"
        Write-Host " $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 1
}

Write-Host "`nDNS Resolution Test:"
$hosts = @("google.com","cloudflare.com","microsoft.com","facebook.com")
foreach ($h in $hosts) {
    $result = Resolve-DnsName $h -ErrorAction SilentlyContinue
    if ($result) {
        Write-Host " $h  Working"
    } else {
        Write-Host " $h  Failed"
    }
}