# Show DNS servers configured on active network adapters
Write-Host "Network Adapters DNS Settings:"

# Get the interface indexes that are actually active (Status = Up)
$activeIndexes = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }).ifIndex

$net = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" |
    Where-Object { $_.InterfaceIndex -in $activeIndexes }

# Check for active adapters before proceeding
if (-not $net) {
    Write-Host "There are currently no enabled network adapters"
    return
}

foreach ($n in $net) {
    Write-Host "`nAdapter: $($n.Description)"

    if ($n.DNSServerSearchOrder) {
        $dnsCount = 1
        foreach ($dns in $n.DNSServerSearchOrder) {
            # Determine the address type: IPv4 or IPv6
            $type = if ($dns -match ':') { "IPv6" } else { "IPv4" }
            Write-Host "  DNS Server ${dnsCount} (${type}): $dns"
            $dnsCount++
        }
    }
    else {
        Write-Host "DNS Servers: Not configured"
    }
}
