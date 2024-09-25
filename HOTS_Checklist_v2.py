import json
import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    
    # Set the tag key, tag value, and retention period
    tag_key = 'DeleteAfter'
    tag_value = '15Days'
    retention_days = 15
    
    # Call the function to delete old snapshots with the specified tag in all regions
    delete_old_snapshots_with_tag(tag_key, tag_value, retention_days)

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda Executed successfully')
    }


def delete_old_snapshots_with_tag(tag_key, tag_value, retention_days):

    # Date range for snapshot deletion
    delete_before = datetime.now() - timedelta(days=retention_days)
    session = boto3.Session()
    # Get all regions
    ec2_regions = session.get_available_regions('ec2')
    print(ec2_regions) # All available regions. This list include non-active regions as well

    for region in ec2_regions:
        try:
            # Create an EC2 client for the current region
            ec2 = boto3.client('ec2', region_name=region)

            # Call the DescribeSnapshots API with tags filter
            response = ec2.describe_snapshots(
                OwnerIds=['self'],
                Filters=[
                    {
                        'Name': 'tag-key',
                        'Values': [tag_key]
                    },
                    {
                        'Name': 'tag-value',
                        'Values': [tag_value]
                    }
                ]
            )

            # Filter tagged snapshots based on date range
            print(response)
            snapshots_to_delete = [snapshot for snapshot in response['Snapshots'] if snapshot['StartTime'].replace(tzinfo=None) < delete_before]
            print(snapshots_to_delete)
            # Delete the snapshots
            for snapshot in snapshots_to_delete:
                ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
                print(f"Deleted snapshot {snapshot['SnapshotId']} from {region} region.")

            print(f"Snapshot deletion completed for {region} region.")

        except Exception as e:
            print(f"Error deleting snapshots from {region} region: {e}")