param (
    [Parameter(Position = 0)]
    [string]$LogPath
)

# Import common logging module
. "$PSScriptRoot\..\Common\Logger.ps1"

# Retrieve processor information via CIM
try {
    $cpuInstances = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop

    if ($cpuInstances) {
        foreach ($cpuInfo in $cpuInstances) {

            Write-Log "Processor Details ($($cpuInfo.DeviceID))"
            Write-Log " Manufacturer:         $($cpuInfo.Manufacturer)"
            Write-Log " Name:                 $($cpuInfo.Name.Trim())"
            Write-Log " Description:          $($cpuInfo.Description)"

            Write-Log "`nArchitecture And Specifications:"
            Write-Log " Architecture:        $($cpuInfo.AddressWidth)-bit"
            Write-Log " Cores:               $($cpuInfo.NumberOfCores)"
            Write-Log " Logical Processors:  $($cpuInfo.NumberOfLogicalProcessors)"

            Write-Log "`nClock Speed:"
            Write-Log " Current Clock:       $([math]::Round($cpuInfo.CurrentClockSpeed, 2)) MHz"
            Write-Log " Max Clock Speed:     $([math]::Round($cpuInfo.MaxClockSpeed, 2)) MHz"

            Write-Log "`nCache Information:"
            Write-Log " L2 Cache Size:       $($cpuInfo.L2CacheSize) KB"
            Write-Log " L3 Cache Size:       $($cpuInfo.L3CacheSize) KB"

            Write-Log "`nStatus And Identification:"
            Write-Log " Device ID:           $($cpuInfo.DeviceID)"
            Write-Log " Processor ID:        $($cpuInfo.ProcessorId)"
            Write-Log " Socket Designation:  $($cpuInfo.SocketDesignation)"

            Write-Log "`nLoad And Status:"
            Write-Log " Current Load:        $($cpuInfo.LoadPercentage)%"
            Write-Log " Status:              $($cpuInfo.Status)"
        }
    } else {
        Write-Log " No processor information found on this system."
    }
} catch {
    Write-Log " Error retrieving processor information: $_"
}