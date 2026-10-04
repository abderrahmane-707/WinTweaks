[CmdletBinding()]
param(
    [switch]$Drive,  # interactive: list ready drive letters, ask for one, print "X:|fs" (or "0|0" = back)
    [switch]$Pick,   # interactive: list all volumes (incl. hidden), print the chosen "target|fs" to stdout
    [switch]$All     # data only: print "target|fs" for every volume to stdout
)

# Display goes to stderr (shown on screen); data goes to stdout (captured by the batch file)
$ErrorActionPreference = 'SilentlyContinue'
$oldEncoding = [Console]::OutputEncoding

try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8   # readable non-English labels

    if ($Drive) {
        $ready = @([IO.DriveInfo]::GetDrives() |
            Where-Object { $_.IsReady -and $_.DriveFormat -and $_.DriveFormat -ne 'RAW' })

        [Console]::Error.WriteLine('Available drives:')
        foreach ($dr in $ready) {
            [Console]::Error.WriteLine(('{0,-5} {1,-8} {2}' -f $dr.Name, $dr.DriveFormat, $dr.VolumeLabel))
        }

        [Console]::Error.Write("`nEnter drive letter (e.g. C), 0 = back: ")
        $c = "$([Console]::ReadLine())".Trim().Trim('"')

        if ($c -eq '0') { '0|0'; return }

        if ($c -notmatch '^([A-Za-z]):?\\?$') {
            [Console]::Error.WriteLine("Invalid drive letter: $c")
            return
        }

        $letter = $Matches[1].ToUpper()
        $sel = $ready | Where-Object { $_.Name.Substring(0, 1) -eq $letter } | Select-Object -First 1
        if (-not $sel) {
            [Console]::Error.WriteLine("Drive ${letter}: is not available.")
            return
        }

        "${letter}:|$($sel.DriveFormat)"
        return
    }

    # Only volumes with a real capacity and a recognized file system
    # (skips empty optical drives / card readers and RAW volumes)
    $vols = @(Get-CimInstance Win32_Volume |
        Where-Object { $_.Capacity -gt 0 -and $_.FileSystem -and $_.FileSystem -ne 'RAW' } |
        Sort-Object @{ e = { if ($_.DriveLetter) { 0 } else { 1 } } }, DriveLetter)

    $rows = for ($i = 0; $i -lt $vols.Count; $i++) {
        $v  = $vols[$i]
        $fs = $v.FileSystem
        # Unlettered volumes: use the volume GUID path (quoted by the batch file)
        $target = if ($v.DriveLetter) { $v.DriveLetter } else { $v.DeviceID.TrimEnd('\') }
        [pscustomobject]@{ N = $i + 1; Vol = $v; FS = $fs; Target = $target }
    }

    if ($All) {
        foreach ($r in $rows) { "$($r.Target)|$($r.FS)" }
        return
    }

    $fmt = '{0,3}  {1,-6} {2,-22} {3,-7} {4,9} {5,9}  {6}'
    [Console]::Error.WriteLine()
    [Console]::Error.WriteLine(($fmt -f '#', 'Letter', 'Label', 'FS', 'Size GB', 'Free GB', 'Notes'))

    foreach ($r in $rows) {
        $v = $r.Vol
        $notes = @()
        if ($v.DirtyBitSet)      { $notes += 'DIRTY' }
        if ($v.SystemVolume)     { $notes += 'system' }
        if ($v.BootVolume)       { $notes += 'boot' }
        if ($v.DriveType -eq 2)  { $notes += 'removable' }
        if (-not $v.DriveLetter) { $notes += 'hidden/no letter' }
        $ltr = if ($v.DriveLetter) { $v.DriveLetter } else { '-' }
        [Console]::Error.WriteLine(($fmt -f $r.N, $ltr, $v.Label, $r.FS,
            [math]::Round($v.Capacity / 1GB, 1), [math]::Round($v.FreeSpace / 1GB, 1), ($notes -join ' ')))
    }

    if ($Pick) {
        [Console]::Error.Write("`nEnter volume number, 0 = back: ")
        $c = "$([Console]::ReadLine())".Trim()

        if ($c -eq '0') { '0|0'; return }

        if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $rows.Count) {
            $sel = $rows[[int]$c - 1]
            "$($sel.Target)|$($sel.FS)"
        } else {
            [Console]::Error.WriteLine('Invalid selection.')
        }
    }
}
finally {
    [Console]::OutputEncoding = $oldEncoding
}
