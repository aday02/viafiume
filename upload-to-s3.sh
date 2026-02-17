#!/bin/bash
# Upload website to S3 bucket
# Make sure you have AWS CLI configured with: aws configure

echo "Uploading website to S3..."
aws s3 sync . s3://viafiume.com \
  --exclude "*.sh" \
  --exclude ".DS_Store" \
  --exclude ".git/*" \
  --exclude ".claude/*" \
  --exclude "node_modules/*" \
  --exclude "lambda/*" \
  --exclude "images/gallery/*" \
  --delete \
  --profile viafiume

echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id E2OE2FPALKHHUZ --paths "/*" --profile viafiume

echo "Upload complete! Your site should be live at: https://viafiume.com"
echo "(CloudFront invalidation may take a few minutes to propagate)"