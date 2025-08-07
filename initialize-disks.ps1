# -------------------------------
# Move DVD drive to X:
# -------------------------------
try {
    $dvd = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE DriveType = 5"
    if ($dvd -and $dvd.DriveLetter -ne 'X:') {
        Set-WmiInstance -InputObject $dvd -Arguments @{DriveLetter = 'X:'}
        Write-Output "DVD drive moved to X:"
    } else {
        Write-Output "DVD drive already assigned to X: or not found."
    }
} catch {
    Write-Warning "Failed to reassign DVD drive: $($_.Exception.Message)"
}

# -------------------------------
# Clean up ghost D: if it's not real
# -------------------------------
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
    Write-Warning "Failed to clean up ghost D: $($_.Exception.Message)"
}

# -------------------------------
# Dynamically assign D-G to data disks
# -------------------------------
$targetDriveLetters = @('D', 'E', 'F', 'G')

try {
    $dataDisks = Get-Disk | Where-Object {
        $_.OperationalStatus -eq 'Online' -and
        $_.Location -match 'LUN'
    }

    $dataDisks = $dataDisks | Sort-Object {
        if ($_ -and $_.Location -match 'LUN (\d+)') {
            [int]$matches[1]
        } else {
            999
        }
    }

    for ($i = 0; $i -lt $dataDisks.Count; $i++) {
        $disk = $dataDisks[$i]
        $driveLetter = $targetDriveLetters[$i]

        if (-not $disk) {
            Write-Warning "Missing disk at index $i, skipping..."
            continue
        }

        # Skip OS disk if it contains C:
        $volumes = Get-Volume -DiskNumber $disk.Number -ErrorAction SilentlyContinue
        if ($volumes -and $volumes.DriveLetter -contains 'C') {
            Write-Warning "Disk #$($disk.Number) is OS disk. Skipping."
            continue
        }

        Write-Output "Processing Disk #$($disk.Number) for drive letter ${driveLetter}:"

        # Initialize if needed
        try {
            if ($disk.PartitionStyle -eq 'RAW') {
                Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
                Write-Output "Initialized Disk #$($disk.Number)"
            }
        } catch {
            Write-Warning "Initialization failed for Disk #$($disk.Number): $($_.Exception.Message)"
        }

        try {
            $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'Reserved' } | Select-Object -First 1

            if (-not $partition) {
                $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter
                Write-Output "Created partition on Disk #$($disk.Number) as ${driveLetter}:"
            } elseif (-not $partition.DriveLetter) {
                $partition | Set-Partition -NewDriveLetter $driveLetter
                Write-Output "Assigned drive letter ${driveLetter}: to existing partition on Disk #$($disk.Number)"
            } elseif ($partition.DriveLetter -ne $driveLetter) {
                Write-Warning "Drive letter mismatch — skipping reassign from $($partition.DriveLetter) to ${driveLetter}:"
            }

            # Format if needed
            $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
            if (-not $volume -or [string]::IsNullOrWhiteSpace($volume.FileSystem)) {
                Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel "DataDisk${driveLetter}" -Confirm:$false -Force
                Write-Output "Formatted DataDisk${driveLetter} on drive ${driveLetter}:"
            } else {
                Write-Output "Drive ${driveLetter}: already formatted as $($volume.FileSystem)"
            }
        } catch {
            Write-Warning "Partition/format failed for Disk #$($disk.Number): $($_.Exception.Message)"
        }
    }
} catch {
    Write-Warning "Top-level disk loop failure: $($_.Exception.Message)"
}

