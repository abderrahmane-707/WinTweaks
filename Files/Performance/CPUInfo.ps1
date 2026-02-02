# Retrieve CPU information using WMI (Windows Management Instrumentation)
$cpuInfo = Get-WmiObject Win32_Processor

Write-Host "Processor Details:"
Write-Host " Manufacturer:  $($cpuInfo.Manufacturer)"
Write-Host " Name:  $($cpuInfo.Name)"
Write-Host " Description:  $($cpuInfo.Description)"

Write-Host "`nArchitecture And Specifications:"
Write-Host " Architecture:  $($cpuInfo.AddressWidth)-bit"
Write-Host " Cores:  $($cpuInfo.NumberOfCores)"
Write-Host " Logical Processors:  $($cpuInfo.NumberOfLogicalProcessors)"

Write-Host "`nClock Speed:"
Write-Host " Current Clock:  $([math]::Round($cpuInfo.CurrentClockSpeed, 2)) MHz"
Write-Host " Max Clock Speed:  $([math]::Round($cpuInfo.MaxClockSpeed, 2)) MHz"

Write-Host "`nCache Information:"
Write-Host " L2 Cache Size:  $($cpuInfo.L2CacheSize) KB"
Write-Host " L3 Cache Size:  $($cpuInfo.L3CacheSize) KB"

Write-Host "`nStatus And Identification:"
Write-Host " Device ID:  $($cpuInfo.DeviceID)"
Write-Host " Processor ID:  $($cpuInfo.ProcessorId)"
Write-Host " Socket Designation:  $($cpuInfo.SocketDesignation)"

Write-Host "`nLoad And Status:"
Write-Host " Current Load:  $($cpuInfo.LoadPercentage)%"
Write-Host " Status:  $($cpuInfo.Status)"