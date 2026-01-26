$net = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
Write-Host "Network Adapters DNS Settings:"
foreach ($n in $net) {
    Write-Host "`n Adapter: $($n.Description)"   
    if ($n.DNSServerSearchOrder -and $n.DNSServerSearchOrder.Count -gt 0) {
        $dnsCount = 1
        foreach ($dns in $n.DNSServerSearchOrder) {
            Write-Host "  DNS Server $dnsCount`: $dns"
            $dnsCount++
        }
    } else {
        Write-Host "  DNS Servers: Not configured"
    }
}