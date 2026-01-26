function Convert-ByteArrayToString {
  param([byte[]]$Bytes)
  return [System.Text.Encoding]::ASCII.GetString($Bytes).TrimEnd("`0")
}

Write-Host "Motherboard Information:"
try {
  $motherboard = Get-WmiObject Win32_BaseBoard
  
  if ($motherboard) {
    Write-Host " Manufacturer:  $($motherboard.Manufacturer)"
    Write-Host " Product/Model:  $($motherboard.Product)"
    Write-Host " Version:  $($motherboard.Version)"
    Write-Host " Serial Number:  $($motherboard.SerialNumber)"
    
    Write-Host " Hosting Board:  $($motherboard.HostingBoard)"
    Write-Host " Hot Swappable:  $($motherboard.HotSwappable)"
    Write-Host " Removable:  $($motherboard.Removable)"
    Write-Host " Replaceable:  $($motherboard.Replaceable)"
    Write-Host " Requires Daughter Board:  $($motherboard.RequiresDaughterBoard)"
  } else {
    Write-Host " No motherboard information found via WMI."
  }
} catch {
  Write-Host " Error accessing motherboard information: $($_.Exception.Message)"
}

Write-Host "`nBIOS/UEFI Information:"
try {
  $firmware = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty PCSystemType
  if ($firmware -eq 2) {
    Write-Host " Firmware Type:  UEFI"
  } elseif ($firmware -eq 1) {
    Write-Host " Firmware Type:  Legacy BIOS"
  } else {
    Write-Host " Firmware Type:  Unknown"
  }
} catch {
    Write-Host " Firmware Type:  Could not determine"
}
try {
  $bios = Get-WmiObject Win32_BIOS
  
  if ($bios) {
    Write-Host " BIOS Manufacturer:  $($bios.Manufacturer)"
    Write-Host " BIOS Name:  $($bios.Name)"
    Write-Host " BIOS Version:  $($bios.Version)"
    Write-Host " BIOS Serial Number:  $($bios.SerialNumber)"
    Write-Host " BIOS Release Date:  $($bios.ReleaseDate)"
  }
} catch {
  Write-Host " Error accessing BIOS information $($_.Exception.Message)"
}

Write-Host "`nSMBIOS Information:"
try {
  $smbios = Get-WmiObject Win32_SMBIOSMemory -ErrorAction SilentlyContinue
  
  if ($smbios) {    
    $smbiosData = Get-WmiObject -Namespace root\wmi -Class MSSmBios_RawSMBiosTables -ErrorAction SilentlyContinue
    
    if ($smbiosData) {
      $smbiosVersion = "$($smbiosData.SmbiosMajorVersion).$($smbiosData.SmbiosMinorVersion)"
      Write-Host " SMBIOS Version:  $smbiosVersion"
      Write-Host " SMBIOS Data Length:  $($smbiosData.Size) bytes"
    }
  }
} catch {
  Write-Host " SMBIOS detailed information not available."
}