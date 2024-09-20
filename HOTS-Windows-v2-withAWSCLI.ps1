# Capture hostname
$hostname = $env:COMPUTERNAME
Write-Output "Hostname: $hostname"

# Capture instance ID
$instanceId = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id)
Write-Output "Instance ID: $instanceId"

# Capture region
$region = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/placement/region)
Write-Output "Region: $region"

# Capture account ID
$accountId = (aws sts get-caller-identity --query "Account" --output text)
Write-Output "Account ID: $accountId"

# Fetch Backup Vault Name
$backupVaultName = (aws backup list-backup-vaults --query "BackupVaultList[0].BackupVaultName" --output text)
Write-Output "Backup Vault Name: $backupVaultName"

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

# Check recovery points or backup jobs in the last week using AWS CLI
$oneWeekAgo = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
aws backup list-recovery-points-by-backup-vault --backup-vault-name $backupVaultName --by-resource-arn arn:aws:ec2:$region:$accountId:instance/$instanceId --query "RecoveryPoints[?CreationDate>=`$oneWeekAgo`]" --output table
