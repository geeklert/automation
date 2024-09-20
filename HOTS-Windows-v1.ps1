# Check if Qualys agent is installed
if (Get-Service -Name "QualysAgent" -ErrorAction SilentlyContinue) {
    Write-Output "Qualys agent is installed."
} else {
    Write-Output "Qualys agent is not installed."
}

# Check if server is domain joined
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Output "Server is domain joined."
} else {
    Write-Output "Server is not domain joined."
}

# Check if CrowdStrike agent is installed
if (Get-Service -Name "CSFalconService" -ErrorAction SilentlyContinue) {
    Write-Output "CrowdStrike agent is installed."
} else {
    Write-Output "CrowdStrike agent is not installed."
}

# Check status of last patches installed
$lastPatch = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastPatch) {
    Write-Output "Last patch installed: $($lastPatch.Description) on $($lastPatch.InstalledOn)"
} else {
    Write-Output "No patches installed recently."
}

# Check if backup is configured
$backupTask = Get-ScheduledTask | Where-Object {$_.TaskName -like "*backup*"}
if ($backupTask) {
    Write-Output "Backup is configured."
} else {
    Write-Output "Backup is not configured."
}
