# Function to print in green
function Print-Green {
    param (
        [string]$Message
    )
    Write-Host $Message -ForegroundColor Green
}

# Function to append to HTML file
function Append-ToHtml {
    param (
        [string]$Content,
        [string]$HtmlFile
    )
    Add-Content -Path $HtmlFile -Value $Content
}

# Detect OS
if ($env:OS -eq "Windows_NT") {
    Print-Green "Running on Windows"

    # Capture hostname
    $hostname = $env:COMPUTERNAME
    Print-Green "Hostname: $hostname"

    # Fetch IMDSv2 token
    $token = Invoke-RestMethod -Method Put -Uri "http://169.254.169.254/latest/api/token" -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"="21600"}

    # Capture instance ID
    $instance_id = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Headers @{"X-aws-ec2-metadata-token"=$token}
    Print-Green "Instance ID: $instance_id"

    # Capture region
    $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" -Headers @{"X-aws-ec2-metadata-token"=$token}
    Print-Green "Region: $region"

    # Capture account ID
    $account_id = (aws sts get-caller-identity --query "Account" --output text)
    Print-Green "Account ID: $account_id"

    # Get today's date
    $today_date = Get-Date -Format "yyyy-MM-dd"

    # Set HTML file name
    $html_file = "${hostname}_${today_date}_${account_id}.html"

    # Start HTML file
    $html_content = @"
<html><head><title>System Information</title><style>body { font-family: Arial, sans-serif; } h2 { color: green; } table { width: 100%; border-collapse: collapse; } th, td { border: 1px solid black; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }</style></head><body>
"@
    Set-Content -Path $html_file -Value $html_content

    Append-ToHtml "<h2>Running on Windows</h2>" $html_file
    Append-ToHtml "<h3>Hostname: $hostname</h3>" $html_file
    Append-ToHtml "<h3>Instance ID: $instance_id</h3>" $html_file
    Append-ToHtml "<h3>Region: $region</h3>" $html_file
    Append-ToHtml "<h3>Account ID: $account_id</h3>" $html_file

    # Fetch Backup Vault Name
    $backup_vault_name = (aws backup list-backup-vaults --query "BackupVaultList[0].BackupVaultName" --output text)
    Append-ToHtml "<h3>Backup Vault Name: $backup_vault_name</h3>" $html_file

    # Check if Qualys agent is installed
    $qualys_status = Get-Service -Name "QualysAgent" -ErrorAction SilentlyContinue
    if ($qualys_status.Status -eq "Running") {
        Append-ToHtml "<h3>Qualys agent is installed and running.</h3>" $html_file
    } else {
        Append-ToHtml "<h3>Qualys agent is not installed or not running.</h3>" $html_file
    }

    # Check if server is domain joined
    $domain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($domain -ne "WORKGROUP") {
        Append-ToHtml "<h3>Server is domain joined.</h3>" $html_file
    } else {
        Append-ToHtml "<h3>Server is not domain joined.</h3>" $html_file
    }

    # Check if CrowdStrike agent is installed
    $crowdstrike_status = Get-Service -Name "CSFalconService" -ErrorAction SilentlyContinue
    if ($crowdstrike_status.Status -eq "Running") {
        Append-ToHtml "<h3>CrowdStrike agent is installed and running.</h3>" $html_file
    } else {
        Append-ToHtml "<h3>CrowdStrike agent is not installed.</h3>" $html_file
    }

    # List details of patches installed
    $patches = Get-HotFix | Select-Object -Property Description, HotFixID, InstalledOn
    Append-ToHtml "<h3>Details of patches installed:</h3><pre>$patches</pre>" $html_file

    # Fetch attached security groups
    $security_groups = (aws ec2 describe-instances --instance-id $instance_id --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)
    Append-ToHtml "<h3>Attached Security Groups: $security_groups</h3>" $html_file

    # Fetch tags applied to the instance
    $tags = (aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" --query "Tags[*].{Key:Key,Value:Value}" --output table)
    Append-ToHtml "<h3>Tags applied to the instance:</h3><pre>$tags</pre>" $html_file

    # Check if volumes attached to this instance are encrypted
    $volumes = (aws ec2 describe-instances --instance-id $instance_id --query "Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId" --output text)
    foreach ($volume in $volumes) {
        $encryption_status = (aws ec2 describe-volumes --volume-ids $volume --query "Volumes[0].Encrypted" --output text)
        Append-ToHtml "<h3>Volume $volume encrypted: $encryption_status</h3>" $html_file
    }

    # Fetch SSM agent version and status
    $ssm_version = (Get-Command "C:\Program Files\Amazon\SSM\amazon-ssm-agent.exe").FileVersionInfo.ProductVersion
    $ssm_status = Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    Append-ToHtml "<h3>SSM Agent Version: $ssm_version</h3>" $html_file
    if ($ssm_status.Status -eq "Running") {
        Append-ToHtml "<h3>SSM Agent Status: Running</h3>" $html_file
    } else {
        Append-ToHtml "<h3>SSM Agent Status: Not Running</h3>" $html_file
    }

    # Check recovery points or backup jobs in the last week using AWS CLI
    $one_week_ago = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $recovery_points = (aws backup list-recovery-points-by-backup-vault --backup-vault-name $backup_vault_name --by-resource-arn "arn:aws:ec2:${region}:${account_id}:instance/${instance_id}" --query "RecoveryPoints[?CreationDate>=`'$one_week_ago'`]" --output table)
    Append-ToHtml "<h3>Recovery Points in the Last Week:</h3><pre>$recovery_points</pre>" $html_file

    # List local users
    $local_users = Get-LocalUser | Select-Object -Property Name
    Append-ToHtml "<h3>Local Users:</h3><pre>$local_users</pre>" $html_file

    # List local groups and their memberships
    $local_groups = Get-LocalGroup | Select-Object -Property Name
    Append-ToHtml "<h3>Local Groups and Memberships:</h3>" $html_file
    foreach ($group in $local_groups) {
        $members = Get-LocalGroupMember -Group $group.Name | Select-Object -Property Name
        Append-ToHtml "<h4>Group: $group.Name</h4>" $html_file
        Append-ToHtml "<p>Members: $members</p>" $html_file
    }

    # End HTML file
    Append-ToHtml "</body></html>" $html_file
} else {
    Write-Host "Unsupported OS type"
}
