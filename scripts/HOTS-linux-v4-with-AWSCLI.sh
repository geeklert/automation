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
    html_file="/tmp/${hostname}_${today_date}_${account_id}.html"

    # Start HTML file
    echo "<html><head><title>System Information</title><style>body { font-family: Arial, sans-serif; } h2 { color: green; } table { width: 100%; border-collapse: collapse; } th, td { border: 1px solid black; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }</style></head><body>" > "$html_file"

    append_to_html "<h2>Running on Linux</h2>"
    append_to_html "<table>"
    append_to_html "<tr><th>Attribute</th><th>Value</th></tr>"
    append_to_html "<tr><td>Hostname</td><td>$hostname</td></tr>"
    append_to_html "<tr><td>Instance ID</td><td>$instance_id</td></tr>"
    append_to_html "<tr><td>Region</td><td>$region</td></tr>"
    append_to_html "<tr><td>Account ID</td><td>$account_id</td></tr>"

    # Fetch Backup Vault Name
    backup_vault_name=$(aws backup list-backup-vaults --query "BackupVaultList[*].BackupVaultName" --output text | awk '{print $1}')
    append_to_html "<tr><td>Backup Vault Name</td><td>$backup_vault_name</td></tr>"

    # Check if Qualys agent is installed
    if systemctl status qualys-cloud-agent | grep "active (running)"; then
        append_to_html "<tr><td>Qualys agent</td><td>Installed and running</td></tr>"
    else
        append_to_html "<tr><td>Qualys agent</td><td>Not installed or not running</td></tr>"
    fi

    # Check if server is domain joined
    if [ "$(realm list | grep 'domain-name')" ]; then
        append_to_html "<tr><td>Domain joined</td><td>Yes</td></tr>"
    else
        append_to_html "<tr><td>Domain joined</td><td>No</td></tr>"
    fi

    # Check if CrowdStrike agent is installed
    if ps -e | grep falcon-sensor; then
        append_to_html "<tr><td>CrowdStrike agent</td><td>Installed and running</td></tr>"
    else
        append_to_html "<tr><td>CrowdStrike agent</td><td>Not installed</td></tr>"
    fi

    # Check if CloudWatch agent is installed and running
    if systemctl status amazon-cloudwatch-agent | grep "active (running)"; then
        append_to_html "<tr><td>CloudWatch agent</td><td>Installed and running</td></tr>"
    else
        append_to_html "<tr><td>CloudWatch agent</td><td>Not installed or not running</td></tr>"
    fi

    # List details of patches installed
    append_to_html "<tr><td>Details of patches installed</td><td><pre>$(yum list installed | grep -i patch)</pre></td></tr>"

    # Fetch attached security groups
    security_groups=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[*].Instances[*].SecurityGroups[*].GroupId" --output text)
    append_to_html "<tr><td>Attached Security Groups</td><td>$security_groups</td></tr>"

    # Fetch tags applied to the instance
    tags=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" --query "Tags[*].{Key:Key,Value:Value}" --output table)
    append_to_html "<tr><td>Tags applied to the instance</td><td><pre>$tags</pre></td></tr>"

    # Check if volumes attached to this instance are encrypted
    volumes=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[*].Instances[*].BlockDeviceMappings[*].Ebs.VolumeId" --output text)
    echo "Volumes: $volumes"
    for volume in $volumes; do
        encryption_status=$(aws ec2 describe-volumes --volume-ids $volume --query "Volumes[*].Encrypted" --output text)
        append_to_html "<tr><td>Volume $volume encrypted</td><td>$encryption_status</td></tr>"
    done

    # Fetch SSM agent version and status
    ssm_version=$(sudo amazon-ssm-agent -version)
    ssm_status=$(systemctl status amazon-ssm-agent | grep "active (running)")
    append_to_html "<tr><td>SSM Agent Version</td><td>$ssm_version</td></tr>"
    append_to_html "<tr><td>SSM Agent Status</td><td>$ssm_status</td></tr>"

    # Check recovery points or backup jobs in the last week using AWS CLI
    one_week_ago=$(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ)
    recovery_points=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name $backup_vault_name --by-resource-arn arn:aws:ec2:$region:$account_id:instance/$instance_id --query "RecoveryPoints[?CreationDate>=\`$one_week_ago\`]" --output table)
    append_to_html "<tr><td>Recovery Points in the Last Week</td><td><pre>$recovery_points</pre></td></tr>"

    # List users with sudo permissions
    sudo_users=$(sudo grep -E '^[^#]*sudo' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | awk -F':' '{print $2}' | tr -d ' ')
    append_to_html "<tr><td>Users with Sudo Permissions</td><td><pre>$sudo_users</pre></td></tr>"

    # List groups with root privileges and their memberships
    append_to_html "<tr><td>Groups with Root Privileges and Memberships</td><td>"
    sudo grep -E '^[^#]*sudo' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | while IFS=: read -r file line; do
      group_name=$(echo $line | awk '{print $1}')
      user_list=$(echo $line | awk '{print $2}')
      if [[ "$group_name" == "root" || "$group_name" == "sudo" ]]; then
         append_to_html "<h4>Group: $group_name</h4>"
         append_to_html "<p>Members: $user_list</p>"
     fi
    done
    append_to_html "</td></tr>"

    append_to_html "</table>"

elif [[ "$OSTYPE" == "msys" ]]; then
    append_to_html "<h2>Running on Windows</h2>"
    powershell.exe -File check_windows.ps1
else
    append_to_html "<h2>Unsupported OS type</h2>"
fi

# End HTML file
append_to_html "</body></html>"

# Upload HTML file to S3
s3_bucket="s3://demo-automation-outputs/HOTS-Checklist"
aws s3 cp "$html_file" "$s3_bucket/$(basename "$html_file")"
