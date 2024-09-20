#!/bin/bash

# Function to get instance details for a given profile and region
get_instance_details() {
    local profile=$1
    local region=$2

    aws ec2 describe-instances --profile "$profile" --region "$region" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,State:State.Name,Platform:Platform,OS:PlatformDetails}' --output table
}

# Get list of AWS profiles
profiles=$(aws configure list-profiles)

# Get list of AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text)

# Loop through each profile and region
for profile in $profiles; do
    for region in $regions; do
        echo "Fetching instance details for profile: $profile in region: $region"
        get_instance_details "$profile" "$region"
    done
done
