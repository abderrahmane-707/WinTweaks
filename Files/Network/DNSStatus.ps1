# Show DNS servers configured on active network adapters
Write-Host "Network Adapters DNS Settings:"

$net = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True"

foreach ($n in $net) {
    Write-Host "`nAdapter: $($n.Description)"

    if ($n.DNSServerSearchOrder) {
        $dnsCount = 1
        foreach ($dns in $n.DNSServerSearchOrder) {
            Write-Host "  DNS Server ${dnsCount}: $dns"
            $dnsCount++
        }
    }
    else {
        Write-Host "  DNS Servers: Not configured"
    }
}