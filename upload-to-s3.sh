#!/bin/bash
# Upload website to S3 bucket
# Make sure you have AWS CLI configured with: aws configure

echo "Uploading website to S3..."
aws s3 sync . s3://viafiume.com --exclude "*.sh" --exclude ".DS_Store" --delete --profile viafiume
echo "Upload complete! Your site should be live at: https://viafiume.com"