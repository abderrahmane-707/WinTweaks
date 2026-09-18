Write-Host "Setting DHCP on all connected interfaces"

# Find all active network adapters
$activeInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Check for active interfaces before proceeding
if (-not $activeInterfaces) {
    Write-Warning "There are currently no active network interfaces"
    return
}

foreach ($adapter in $activeInterfaces) {
    $interfaceName = $adapter.Name
    $interfaceIndex = $adapter.ifIndex

    Write-Host "  - Resetting: $interfaceName"

    # Enable DHCP (IPv4)
    try {
        Set-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -DHCP Enabled -ErrorAction Stop
    }
    catch {
        Write-Host " Failed to enable IPv4 DHCP on $($interfaceName): $_"
    }

    # Enable DHCP (IPv6) - only if the interface supports it
    try {
        Set-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv6 -DHCP Enabled -ErrorAction Stop
    }
    catch {
        Write-Host " Failed to enable IPv6 DHCP on $($interfaceName): $_"
    }

    # Reset DNS addresses
    try {
        Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ResetServerAddresses -ErrorAction Stop
    }
    catch {
        Write-Host " Failed to reset DNS on $($interfaceName): $_"
    }
}

Write-Host "`nFlushing DNS cache"
Clear-DnsClientCache -ErrorAction Stop
