# install-and-schedule.ps1

$log = "C:\Temp\disk-schedule.log"
"[$(Get-Date)] Starting install-and-schedule.ps1" | Out-File -FilePath $log -Encoding utf8 -Append

try {
    # Define path for the actual disk initialization script
    $scriptPath = "C:\Temp\initialize-disks.ps1"
    $taskName   = "Initialize-Disks-PostBoot"

    # Ensure Temp folder exists
    if (-not (Test-Path "C:\Temp")) {
        New-Item -Path "C:\Temp" -ItemType Directory | Out-Null
    }

    # Copy disk script if missing
    if (-not (Test-Path $scriptPath)) {
        Copy-Item -Path ".\initialize-disks.ps1" -Destination $scriptPath -Force
        "[$(Get-Date)] Copied initialize-disks.ps1 to $scriptPath" | Out-File -FilePath $log -Append
    }

    # Define task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup 
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    # Register it
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force
    "[$(Get-Date)] Scheduled task '$taskName' created successfully." | Out-File -FilePath $log -Append
} catch {
    "[$(Get-Date)] ERROR: $($_.Exception.Message)" | Out-File -FilePath $log -Append
}
