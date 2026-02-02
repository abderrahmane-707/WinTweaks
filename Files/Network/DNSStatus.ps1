Write-Host "Network Adapters DNS Settings:"

# Retrieve all network adapter configurations that are currently IP-enabled
$net = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }

# Loop through each IP-enabled network adapter
foreach ($n in $net) {
    # Display the adapter description/name with a newline before each adapter
    Write-Host "`n Adapter: $($n.Description)"   
    
    # Check if DNS servers are configured for this adapter
    if ($n.DNSServerSearchOrder -and $n.DNSServerSearchOrder.Count -gt 0) {
        # Initialize counter for displaying DNS servers in order (primary, secondary, etc.)
        $dnsCount = 1
        
        # Loop through each DNS server IP address in the search order
        foreach ($dns in $n.DNSServerSearchOrder) {
            # Display each DNS server with its priority number
            Write-Host "  DNS Server $dnsCount`: $dns"
            $dnsCount++
        }
    } else {
        # No DNS servers are configured for this adapter
        Write-Host "  DNS Servers: Not configured"
    }
}