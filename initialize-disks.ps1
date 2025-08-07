Start-Sleep -Seconds 60

# Reletter DVD drive to X:
try {
    $dvd = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveType = 5"
    if ($dvd -and $dvd.DriveLetter -ne 'X:') {
        Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter = 'X:'}
        Write-Output "DVD drive moved to X:"
    } else {
        Write-Output "DVD drive already assigned to X: or not found."
    }
} catch {
    Write-Warning "Failed to process DVD drive relettering: $($_.Exception.Message)"
}

# Clean up ghost D: mount if it exists and is invalid
try {
    $ghostD = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
    if ($ghostD -and ([string]::IsNullOrWhiteSpace($ghostD.FileSystemType) -or $ghostD.Size -lt 1GB)) {
        $partition = Get-Partition | Where-Object { $_.AccessPaths -contains "D:\" }
        if ($partition) {
            Remove-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath "D:\"
            Write-Output "Removed ghost D: mount from Disk #$($partition.DiskNumber)"
        }
    }
} catch {
    Write-Warning "Failed to remove ghost D: access path: $($_.Exception.Message)"
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
    try {
        for ($i = 0; $i -lt 6 -and -not $disk; $i++) {
            # Get OS disk number (volume mounted as C:\)
            $osDiskNumber = (Get-Partition | Where-Object { $_.DriveLetter -eq 'C' }).DiskNumber

            # Look for matching LUN, skipping the OS disk
            $disk = Get-Disk | Where-Object { $_.Location -match "LUN $lun" -and $_.Number -ne $osDiskNumber }

            if (-not $disk) {
                Start-Sleep -Seconds 5
            }
        }
    } catch {
        Write-Warning "Error while polling for LUN ${lun}: $($_.Exception.Message)"
    }

    if (-not $disk) {
        Write-Warning "No disk found for LUN ${lun} after waiting. Skipping."
        continue
    }

    Write-Output "Found disk at LUN ${lun} (Disk #$($disk.Number))"

    # Initialize if needed
    try {
        if ($disk.PartitionStyle -eq 'RAW') {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            Write-Output "Initialized Disk #$($disk.Number) (LUN ${lun})"
        }
    } catch {
        Write-Warning "Initialization failed for Disk #$($disk.Number): $($_.Exception.Message)"
    }

    # Create/assign partition and format
    try {
        # Get non-reserved partition larger than 1GB if it exists
        $partition = Get-Partition -DiskNumber $disk.Number | Where-Object {
            $_.Type -ne 'Reserved' -and $_.Size -gt 1GB
        } | Select-Object -First 1

        if (-not $partition) {
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter
            Write-Output "Created partition on Disk #$($disk.Number) with drive letter ${driveLetter}:"
        } elseif (-not $partition.DriveLetter) {
            $partition | Set-Partition -NewDriveLetter $driveLetter
            Write-Output "Assigned drive letter ${driveLetter}: to existing partition on Disk #$($disk.Number)"
        } elseif ($partition.DriveLetter -ne $driveLetter) {
            Write-Warning "Drive letter mismatch - skipping reassign of $($partition.DriveLetter) to ${driveLetter}:"
        }

        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
        if (-not $volume -or [string]::IsNullOrWhiteSpace($volume.FileSystem)) {
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "DataDisk${driveLetter}" -Confirm:$false -Force
            Write-Output "Formatted DataDisk${driveLetter} on drive ${driveLetter}:"
        } else {
            Write-Output "Drive ${driveLetter}: already formatted as $($volume.FileSystem)"
        }
    } catch {
        Write-Warning "Partition or formatting failed for Disk #$($disk.Number): $($_.Exception.Message)"
    }
}
