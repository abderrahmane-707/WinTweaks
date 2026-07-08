param (
    [Parameter(Mandatory=$true)][string]$DnsIPv4Primary,
    [Parameter(Mandatory=$true)][string]$DnsIPv4Secondary,
    [Parameter(Mandatory=$true)][string]$DnsIPv6Primary,
    [Parameter(Mandatory=$true)][string]$DnsIPv6Secondary
)

# Find all active network adapters
$activeInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Combine all DNS addresses into a single array (filtering out empty values)
$DnsServers = @($DnsIPv4Primary, $DnsIPv4Secondary, $DnsIPv6Primary, $DnsIPv6Secondary) | Where-Object { $_ -ne "" }

foreach ($adapter in $activeInterfaces) {
    $interfaceName = $adapter.Name
    
    Write-Host "  - Configure: $interfaceName"
    
    try {
        # Apply all DNS settings in one clean operation
        Set-DnsClientServerAddress -InterfaceAlias $interfaceName -ServerAddresses $DnsServers -ErrorAction Stop
    }
    catch {
        Write-Host " Failed to set DNS for interface [$interfaceName]: $_"
    }
}

Write-Host "`nFlushing DNS cache"
Clear-DnsClientCache -ErrorAction Stop