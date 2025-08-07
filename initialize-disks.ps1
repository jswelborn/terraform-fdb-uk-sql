Start-Sleep -Seconds 90

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

# Define LUN-to-drive-letter and label mappings
$lunMap = @{
    0 = @{ DriveLetter = 'D'; Label = 'EDBS' }
    1 = @{ DriveLetter = 'E'; Label = 'SQLInstance' }
    2 = @{ DriveLetter = 'F'; Label = 'Data' }
    3 = @{ DriveLetter = 'G'; Label = 'Log' }
		4 = @{ DriveLetter = 'H'; Label = 'Temporary Storage' }
}

foreach ($lun in $lunMap.Keys) {
    $driveLetter = $lunMap[$lun].DriveLetter
    $volumeLabel = $lunMap[$lun].Label

    $disk = $null
    try {
        for ($i = 0; $i -lt 6 -and -not $disk; $i++) {
            $osDiskNumber = (Get-Partition | Where-Object { $_.DriveLetter -eq 'C' }).DiskNumber
            $disk = Get-Disk | Where-Object { $_.Location -match "LUN $lun" -and $_.Number -ne $osDiskNumber }
            if (-not $disk) { Start-Sleep -Seconds 5 }
        }
    } catch {
        Write-Warning "Error while polling for LUN ${lun}: $($_.Exception.Message)"
    }

    if (-not $disk) {
        Write-Warning "No disk found for LUN ${lun} after waiting. Skipping."
        continue
    }

    Write-Output "Found disk at LUN ${lun} (Disk #$($disk.Number))"

    try {
        if ($disk.PartitionStyle -eq 'RAW') {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false
            Write-Output "Initialized Disk #$($disk.Number) (LUN ${lun})"
        }
    } catch {
        Write-Warning "Initialization failed for Disk #$($disk.Number): $($_.Exception.Message)"
    }

    try {
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
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel $volumeLabel -Confirm:$false -Force
            Write-Output "Formatted $volumeLabel on drive ${driveLetter}:"
        } else {
            Write-Output "Drive ${driveLetter}: already formatted as $($volume.FileSystem)"
        }
    } catch {
        Write-Warning "Partition or formatting failed for Disk #$($disk.Number): $($_.Exception.Message)"
    }
}
