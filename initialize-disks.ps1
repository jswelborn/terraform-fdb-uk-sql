# Reletter DVD drive to X:
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

# Clean up ghost D: mount if it exists and is invalid
$ghostD = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
if ($ghostD -and ([string]::IsNullOrWhiteSpace($ghostD.FileSystemType) -or $ghostD.Size -eq 0)) {
    try {
        $partition = Get-Partition | Where-Object { $_.AccessPaths -contains "D:\" }
        if ($partition) {
            Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "D:\"
            Write-Output "Removed ghost D: mount from Disk #$($partition.DiskNumber)"
        }
    } catch {
        Write-Warning "Failed to remove ghost D: access path: $($_.Exception.Message)"
    }
}

# Define expected LUN-to-drive-letter mappings
$lunMap = @{
    0 = 'D'
    1 = 'E'
    2 = 'F'
    3 = 'G'
}

foreach ($lun in $lunMap.Keys) {
    $driveLetter = $lunMap[$lun]

    # Wait for disk at LUN to appear (retry 6x, up to 30 seconds)
    $disk = $null
    for ($i = 0; $i -lt 6 -and -not $disk; $i++) {
        $disk = Get-Disk | Where-Object { $_.Location -match "LUN $lun" }
        if (-not $disk) { Start-Sleep -Seconds 5 }
    }

    if (-not $disk) {
        Write-Warning "No disk found for LUN $lun after waiting. Skipping."
        continue
    }

    Write-Output "Found disk at LUN $lun (Disk #$($disk.Number))"

    # Initialize if needed
    if ($disk.PartitionStyle -eq 'RAW') {
        try {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            Write-Output "Initialized Disk #$($disk.Number) (LUN $lun)"
        } catch {
            Write-Warning "Initialization failed: $($_.Exception.Message)"
        }
    }

    try {
        $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'Reserved' } | Select-Object -First 1

        if (-not $partition) {
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter
            Write-Output "Created partition on Disk #$($disk.Number) with drive letter ${driveLetter}:"
        } elseif (-not $partition.DriveLetter) {
            $partition | Set-Partition -NewDriveLetter $driveLetter
            Write-Output "Assigned drive letter ${driveLetter}: to existing partition on Disk #$($disk.Number)"
        } elseif ($partition.DriveLetter -ne $driveLetter) {
            Write-Warning "Drive letter mismatch — skipping reassign of $($partition.DriveLetter) to ${driveLetter}:"
        }

        # Format if needed
        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
        if (-not $volume -or [string]::IsNullOrWhiteSpace($volume.FileSystem)) {
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "DataDisk$driveLetter" -Confirm:$false -Force
            Write-Output "Formatted DataDisk$driveLetter on drive ${driveLetter}:"
        } else {
            Write-Output "Drive ${driveLetter}: already formatted as $($volume.FileSystem)"
        }

    } catch {
        Write-Warning "Partition or formatting failed for Disk #$($disk.Number): $($_.Exception.Message)"
    }
}
