#!/bin/bash

# Function to print in green
print_green() {
    echo -e "\e[32m$1\e[0m"
}

# Function to append to CSV file
append_to_csv() {
    echo "$1" >> "$csv_file"
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

    # Set CSV file name
    csv_file="/tmp/system_info_${today_date}.csv"

    # Check if CSV file exists, if not create it with headers
    if [ ! -f "$csv_file" ]; then
        echo "Instance ID,Attribute,Value" > "$csv_file"
    fi

    append_to_csv "$instance_id,Running on Linux,"
    append_to_csv "$instance_id,Hostname,$hostname"
    append_to_csv "$instance_id,Instance ID,$instance_id"
    append_to_csv "$instance_id,Region,$region"
    append_to_csv "$instance_id,Account ID,$account_id"

    # Fetch Backup Vault Name
    backup_vault_name=$(aws backup list-backup-vaults --query "BackupVaultList[*].BackupVaultName" --output text | awk '{print $1}')
    append_to_csv "$instance_id,Backup Vault Name,$backup_vault_name"

    # Check if Qualys agent is installed
    if systemctl status qualys-cloud-agent | grep "active (running)"; then
        append_to_csv "$instance_id,Qualys agent,Installed and running"
    else
        append_to_csv "$instance_id,Qualys agent,Not installed or not running"
    fi

    # Check if server is domain joined
    if [ "$(realm list | grep 'domain-name')" ]; then
        append_to_csv "$instance_id,Domain joined,Yes"
    else
        append_to_csv "$instance_id,Domain joined,No"
    fi

    # Check if CrowdStrike agent is installed
    if ps -e | grep falcon-sensor; then
        append_to_csv "$instance_id,CrowdStrike agent,Installed and running"
    else
        append_to_csv "$instance_id,CrowdStrike agent,Not installed"
    fi

    # Check if CloudWatch agent is installed and running
    if systemctl status amazon-cloudwatch-agent | grep "active (running)"; then
        append_to_csv "$instance_id,CloudWatch agent,Installed and running"
    else
        append_to_csv "$instance_id,CloudWatch agent,Not installed or not running"
    fi

    # List details of patches installed
    append_to_csv "$instance_id,Details of patches installed,\"$(yum list installed | grep -i patch | tr '\n' ';')\""

    # Fetch attached security groups
    security_groups=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[*].Instances[*].SecurityGroups[*].GroupId" --output text)
    append_to_csv "$instance_id,Attached Security Groups,$security_groups"

    # Fetch tags applied to the instance
    tags=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" --query "Tags[*].{Key:Key,Value:Value}" --output table | tr '\n' ';')
    append_to_csv "$instance_id,Tags applied to the instance,\"$tags\""

    # Check if volumes attached to this instance are encrypted
    volumes=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[*].Instances[*].BlockDeviceMappings[*].Ebs.VolumeId" --output text)
    echo "Volumes: $volumes"
    for volume in $volumes; do
        encryption_status=$(aws ec2 describe-volumes --volume-ids $volume --query "Volumes[*].Encrypted" --output text)
        append_to_csv "$instance_id,Volume $volume encrypted,$encryption_status"
    done

    # Fetch SSM agent version and status
    ssm_version=$(sudo amazon-ssm-agent -version)
    ssm_status=$(systemctl status amazon-ssm-agent | grep "active (running)")
    append_to_csv "$instance_id,SSM Agent Version,$ssm_version"
    append_to_csv "$instance_id,SSM Agent Status,$ssm_status"

    # Check recovery points or backup jobs in the last week using AWS CLI
    one_week_ago=$(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ)
    recovery_points=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name $backup_vault_name --by-resource-arn arn:aws:ec2:$region:$account_id:instance/$instance_id --query "RecoveryPoints[?CreationDate>=\`$one_week_ago\`]" --output table | tr '\n' ';')
    append_to_csv "$instance_id,Recovery Points in the Last Week,\"$recovery_points\""

    # List users with sudo permissions
    sudo_users=$(sudo grep -E '^[^#]*sudo' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | awk -F':' '{print $2}' | tr -d ' ' | tr '\n' ';')
    append_to_csv "$instance_id,Users with Sudo Permissions,\"$sudo_users\""

    # List groups with root privileges and their memberships
    append_to_csv "$instance_id,Groups with Root Privileges and Memberships,"
    sudo grep -E '^[^#]*sudo' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | while IFS=: read -r file line; do
      group_name=$(echo $line | awk '{print $1}')
      user_list=$(echo $line | awk '{print $2}')
      if [[ "$group_name" == "root" || "$group_name" == "sudo" ]]; then
         append_to_csv "$instance_id,Group: $group_name,Members: $user_list"
     fi
    done

elif [[ "$OSTYPE" == "msys" ]]; then
    append_to_csv "Running on Windows,"
    powershell.exe -File check_windows.ps1
else
    append_to_csv "Unsupported OS type,"
fi

# Upload CSV file to S3
s3_bucket="s3://demo-automation-outputs/HOTS-Checklist"
aws s3 cp "$csv_file" "$s3_bucket/$(basename "$csv_file")"
