# Define path for the actual disk initialization script
$scriptPath = "C:\Temp\initialize-disks.ps1"
$taskName   = "Initialize-Disks-PostBoot"

# Create the Temp directory if it doesn't exist
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
}

# Copy the script if it doesn't already exist
if (-not (Test-Path $scriptPath)) {
    Copy-Item -Path ".\initialize-disks.ps1" -Destination $scriptPath -Force
    Write-Output "Copied initialize-disks.ps1 to $scriptPath"
}

# Define a scheduled task action and trigger
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup -Delay "PT2M"  # Delay = 2 minutes after boot
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

# Register the scheduled task
try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force
    Write-Output "Scheduled task '$taskName' created to run $scriptPath at next boot with 2-minute delay."
} catch {
    Write-Warning "Failed to create scheduled task: $($_.Exception.Message)"
}
