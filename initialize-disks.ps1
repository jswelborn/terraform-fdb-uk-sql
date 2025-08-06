# Move DVD drive to X: to free up D:
$dvd = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveType = 5"
if ($dvd -and $dvd.DriveLetter -ne 'X:') {
    try {
        Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter = 'X:'}
        Write-Output "DVD drive moved to X:"
    } catch {
        Write-Warning "Failed to move DVD drive: $($_.Exception.Message)"
    }
} else {
    Write-Output "DVD drive already assigned to X: or not found."
}

# Define LUN-to-drive-letter map
$lunMap = @{
    0 = 'D'
    1 = 'E'
    2 = 'F'
    3 = 'G'
}

foreach ($lun in $lunMap.Keys) {
    $driveLetter = $lunMap[$lun]
    $disk = Get-Disk | Where-Object { $_.Location -match "LUN $lun" }

    if ($disk) {
        if ($disk.PartitionStyle -eq 'RAW') {
            try {
                Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
                Write-Output "Initialized disk with LUN $lun (Disk #$($disk.Number))"
            } catch {
                Write-Warning "Disk already initialized: $($_.Exception.Message)"
            }
        }

        try {
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "DataDisk$driveLetter" -Confirm:$false -Force
            Write-Output "Formatted and mounted DataDisk$driveLetter on drive ${driveLetter}:"
        } catch {
            Write-Warning "Failed to partition or format disk: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "No disk found with LUN $lun"
    }
}
