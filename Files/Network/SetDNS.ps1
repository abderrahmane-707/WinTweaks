param (
    [Parameter(Mandatory=$true)][string]$DnsIPv4Primary,
    [Parameter(Mandatory=$true)][string]$DnsIPv4Secondary,
    [Parameter(Mandatory=$true)][string]$DnsIPv6Primary,
    [Parameter(Mandatory=$true)][string]$DnsIPv6Secondary
)

# Find all active network adapters
$activeInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Check whether there are active interfaces before continuing
if (-not $activeInterfaces) {
    Write-Warning "There are currently no active network interfaces"
    return
}

# Combine all DNS addresses into a single array
$DnsServers = @($DnsIPv4Primary, $DnsIPv4Secondary, $DnsIPv6Primary, $DnsIPv6Secondary) | Where-Object { $_ -ne "" }

foreach ($adapter in $activeInterfaces) {
    $interfaceName = $adapter.Name

    Write-Host "  - Configure: $interfaceName"

    try {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DnsServers -ErrorAction Stop
    }
    catch {
        Write-Host " Failed to set DNS for interface [$interfaceName]: $_"
    }
}

Write-Host "Flushing DNS cache"
Clear-DnsClientCache -ErrorAction Stop
