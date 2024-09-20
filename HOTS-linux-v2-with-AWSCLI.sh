#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Running on Linux"

    # Capture hostname
    hostname=$(hostname)
    echo "Hostname: $hostname"

    # Capture instance ID
    instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "Instance ID: $instance_id"

    # Capture region
    region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    echo "Region: $region"

    # Capture account ID
    account_id=$(aws sts get-caller-identity --query "Account" --output text)
    echo "Account ID: $account_id"

    # Fetch Backup Vault Name
    backup_vault_name=$(aws backup list-backup-vaults --query "BackupVaultList[0].BackupVaultName" --output text)
    echo "Backup Vault Name: $backup_vault_name"

    # Check if Qualys agent is installed
    if systemctl status qualys-cloud-agent | grep "active (running)"; then
        echo "Qualys agent is installed and running."
    else
        echo "Qualys agent is not installed or not running."
    fi

    # Check if server is domain joined
    if [ "$(realm list | grep 'domain-name')" ]; then
        echo "Server is domain joined."
    else
        echo "Server is not domain joined."
    fi

    # Check if CrowdStrike agent is installed
    if ps -e | grep falcon-sensor; then
        echo "CrowdStrike agent is installed and running."
    else
        echo "CrowdStrike agent is not installed."
    fi

    # Check status of last patches installed
    last_patch=$(yum history | grep -m 1 "Install" | awk '{print $1}')
    if [ -n "$last_patch" ]; then
        echo "Last patch installed: $last_patch"
    else
        echo "No patches installed recently."
    fi

    # Check if backup is configured
    if crontab -l | grep -q "backup"; then
        echo "Backup is configured."
    else
        echo "Backup is not configured."
    fi

    # Check recovery points or backup jobs in the last week using AWS CLI
    one_week_ago=$(date -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ)
    aws backup list-recovery-points-by-backup-vault --backup-vault-name $backup_vault_name --by-resource-arn arn:aws:ec2:$region:$account_id:instance/$instance_id --query "RecoveryPoints[?CreationDate>=\`$one_week_ago\`]" --output table

elif [[ "$OSTYPE" == "msys" ]]; then
    echo "Running on Windows"
    powershell.exe -File check_windows.ps1
else
    echo "Unsupported OS type"
fi
