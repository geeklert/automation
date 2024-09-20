#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Running on Linux"

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

elif [[ "$OSTYPE" == "msys" ]]; then
    echo "Running on Windows"
    powershell.exe -File check_windows.ps1
else
    echo "Unsupported OS type"
fi
