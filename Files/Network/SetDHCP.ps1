Write-Host "Setting DHCP on all connected interfaces"

# Find all active network adapters
$activeInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

foreach ($adapter in $activeInterfaces) {
    $interfaceName = $adapter.Name
    
    Write-Host "  - Resetting: $interfaceName"
    
    try {
		# Enable DHCP
        Set-NetIPInterface -InterfaceAlias $interfaceName -AddressFamily IPv4 -DHCP Enabled -ErrorAction Stop
        
        # Reset DNS addresses
        Set-DnsClientServerAddress -InterfaceAlias $interfaceName -ResetServerAddresses -ErrorAction Stop
        
    }
    catch {
        Write-Host " Failed to reset $($interfaceName): $_"
    }
}

Write-Host "`nFlushing DNS cache"
Clear-DnsClientCache -ErrorAction Stop