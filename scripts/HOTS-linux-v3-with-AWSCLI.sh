#!/bin/bash

# Function to print in green
print_green() {
    echo -e "\e[32m$1\e[0m"
}

# Function to append to HTML file
append_to_html() {
    echo "$1" >> "$html_file"
}

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_green "Running on Linux"

    # Capture hostname
    hostname=$(hostname)
    print_green "Hostname: $hostname"

    # Fetch IMDSv2 token
    token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    # Capture instance ID
    instance_id=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
    print_green "Instance ID: $instance_id"

    # Capture region
    region=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/placement/region)
    print_green "Region: $region"

    # Capture account ID
    account_id=$(aws sts get-caller-identity --query "Account" --output text)
    print_green "Account ID: $account_id"

    # Get today's date
    today_date=$(date +%Y-%m-%d)

    # Set HTML file name
    html_file="${hostname}_${today_date}_${account_id}.html"

    # Start HTML file
    echo "<html><head><title>System Information</title><style>body { font-family: Arial, sans-serif; } h2 { color: green; } table { width: 100%; border-collapse: collapse; } th, td { border: 1px solid black; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }</style></head><body>" > "$html_file"

    append_to_html "<h2>Running on Linux</h2>"
    append_to_html "<h3>Hostname: $hostname</h3>"
    append_to_html "<h3>Instance ID: $instance_id</h3>"
    append_to_html "<h3>Region: $region</h3>"
    append_to_html "<h3>Account ID: $account_id</h3>"

    # Fetch Backup Vault Name
    backup_vault_name=$(aws backup list-backup-vaults --query "BackupVaultList[0].BackupVaultName" --output text)
    append_to_html "<h3>Backup Vault Name: $backup_vault_name</h3>"

    # Check if Qualys agent is installed
    if systemctl status qualys-cloud-agent | grep "active (running)"; then
        append_to_html "<h3>Qualys agent is installed and running.</h3>"
    else
        append_to_html "<h3>Qualys agent is not installed or not running.</h3>"
    fi

    # Check if server is domain joined
    if [ "$(realm list | grep 'domain-name')" ]; then
        append_to_html "<h3>Server is domain joined.</h3>"
    else
        append_to_html "<h3>Server is not domain joined.</h3>"
    fi

    # Check if CrowdStrike agent is installed
    if ps -e | grep falcon-sensor; then
        append_to_html "<h3>CrowdStrike agent is installed and running.</h3>"
    else
        append_to_html "<h3>CrowdStrike agent is not installed.</h3>"
    fi

    # List details of patches installed
    append_to_html "<h3>Details of patches installed:</h3><pre>$(yum list installed | grep -i patch)</pre>"

    # Fetch attached security groups
    security_groups=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)
    append_to_html "<h3>Attached Security Groups: $security_groups</h3>"

    # Fetch tags applied to the instance
    tags=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" --query "Tags[*].{Key:Key,Value:Value}" --output table)
    append_to_html "<h3>Tags applied to the instance:</h3><pre>$tags</pre>"

    # Check if volumes attached to this instance are encrypted
    volumes=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId" --output text)
    for volume in $volumes; do
        encryption_status=$(aws ec2 describe-volumes --volume-ids $volume --query "Volumes[0].Encrypted" --output text)
        append_to_html "<h3>Volume $volume encrypted: $encryption_status</h3>"
    done

    # Fetch SSM agent version and status
    ssm_version=$(sudo amazon-ssm-agent -version)
    ssm_status=$(systemctl status amazon-ssm-agent | grep "active (running)")
    append_to_html "<h3>SSM Agent Version: $ssm_version</h3>"
    append_to_html "<h3>SSM Agent Status: $ssm_status</h3>"

    # Check recovery points or backup jobs in the last week using AWS CLI
    one_week_ago=$(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ)
    recovery_points=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name $backup_vault_name --by-resource-arn arn:aws:ec2:$region:$account_id:instance/$instance_id --query "RecoveryPoints[?CreationDate>=\`$one_week_ago\`]" --output table)
    append_to_html "<h3>Recovery Points in the Last Week:</h3><pre>$recovery_points</pre>"

    # List users with sudo permissions
    append_to_html "<h3>Users with Sudo Permissions:</h3><pre>$(getent group sudo | cut -d: -f4)</pre>"

    # List groups with root privileges and their memberships
    append_to_html "<h3>Groups with Root Privileges and Memberships:</h3>"
    getent group | while IFS=: read -r group_name _ _ user_list; do
      if [[ "$group_name" == "root" || "$group_name" == "sudo" ]]; then
         append_to_html "<h4>Group: $group_name</h4>"
         append_to_html "<p>Members: $user_list</p>"
     fi
    done


elif [[ "$OSTYPE" == "msys" ]]; then
    append_to_html "<h2>Running on Windows</h2>"
    powershell.exe -File check_windows.ps1
else
    append_to_html "<h2>Unsupported OS type</h2>"
fi

# End HTML file
append_to_html "</body></html>"
