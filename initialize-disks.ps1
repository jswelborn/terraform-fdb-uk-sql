$dvd = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveType = 5"
if ($dvd -and $dvd.DriveLetter -ne 'X:') {
    Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter = 'X:'}
}

$lunMap = New-Object 'System.Collections.Generic.Dictionary[Int32,string]'
$lunMap.Add(0, 'D')
$lunMap.Add(1, 'E')
$lunMap.Add(2, 'F')
$lunMap.Add(3, 'G')

foreach ($lun in $lunMap.Keys) {
    $driveLetter = $lunMap[$lun]
    $disk = Get-Disk | Where-Object { $_.Location -match "LUN $lun" }

    if ($disk) {
        if ($disk.PartitionStyle -eq 'RAW') {
            try {
                Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            } catch {
                Write-Warning "Disk $($disk.Number) already initialized"
            }
        }

        try {
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel \"DataDisk$driveLetter\" -Confirm:$false -Force
        } catch {
            Write-Warning "Partition or format failed on LUN $lun ($($disk.Number))"
        }
    }
}
