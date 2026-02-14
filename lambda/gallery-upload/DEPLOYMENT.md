# Gallery Upload Lambda Deployment Guide

This guide will help you set up the Lambda function and API Gateway to enable image uploads to your gallery.

## Prerequisites

- AWS CLI configured with your `viafiume` profile
- Node.js installed on your machine
- AWS Account with permissions to create Lambda functions, API Gateway, and IAM roles

## Step 1: Package the Lambda Function

1. Navigate to the lambda directory:
```bash
cd "c:\Users\aday0\OneDrive\Dev\viaFiume_Laptop\lambda\gallery-upload"
```

2. Install dependencies:
```bash
npm install
```

3. Create a deployment package:
```bash
# Create a zip file with the function code and dependencies
powershell Compress-Archive -Path index.js,node_modules,package.json -DestinationPath function.zip -Force
```

## Step 2: Create IAM Role for Lambda

The Lambda function needs permissions to:
- Read/Write to S3 bucket
- Create CloudFront invalidations
- Write CloudWatch Logs

```bash
# Create trust policy file
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role
aws iam create-role \
  --role-name GalleryUploadLambdaRole \
  --assume-role-policy-document file://trust-policy.json \
  --profile viafiume

# Attach basic Lambda execution policy
aws iam attach-role-policy \
  --role-name GalleryUploadLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --profile viafiume

# Create custom policy for S3 and CloudFront access
cat > lambda-permissions.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::viafiume.com/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name GalleryUploadLambdaRole \
  --policy-name GalleryUploadPolicy \
  --policy-document file://lambda-permissions.json \
  --profile viafiume
```

## Step 3: Create Lambda Function

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile viafiume)

# Create the Lambda function
aws lambda create-function \
  --function-name GalleryUploadFunction \
  --runtime nodejs18.x \
  --handler index.handler \
  --role arn:aws:iam::${ACCOUNT_ID}:role/GalleryUploadLambdaRole \
  --zip-file fileb://function.zip \
  --timeout 30 \
  --memory-size 512 \
  --profile viafiume
```

## Step 4: Create API Gateway

```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
  --name "GalleryUploadAPI" \
  --description "API for uploading images to gallery" \
  --profile viafiume \
  --query 'id' \
  --output text)

echo "API ID: $API_ID"

# Get the root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --profile viafiume \
  --query 'items[0].id' \
  --output text)

# Create /upload resource
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part upload \
  --profile viafiume \
  --query 'id' \
  --output text)

# Create POST method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --profile viafiume

# Set up Lambda integration
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:GalleryUploadFunction/invocations \
  --profile viafiume

# Add CORS support - OPTIONS method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method OPTIONS \
  --authorization-type NONE \
  --profile viafiume

aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers": false,"method.response.header.Access-Control-Allow-Methods": false,"method.response.header.Access-Control-Allow-Origin": false}' \
  --profile viafiume

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
  --profile viafiume

aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{"method.response.header.Access-Control-Allow-Headers": "'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods": "'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin": "'"'"'*'"'"'"}' \
  --profile viafiume

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name GalleryUploadFunction \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:${ACCOUNT_ID}:${API_ID}/*/*" \
  --profile viafiume

# Deploy API
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --profile viafiume

# Get the API endpoint
echo "Your API Gateway endpoint:"
echo "https://${API_ID}.execute-api.us-east-1.amazonaws.com/prod/upload"
```

## Step 5: Update gallery.html

1. Copy the API Gateway endpoint from the output above
2. Open `pages/gallery.html`
3. Find the line:
```javascript
const UPLOAD_API_ENDPOINT = 'YOUR_API_GATEWAY_ENDPOINT_HERE';
```
4. Replace it with your actual endpoint:
```javascript
const UPLOAD_API_ENDPOINT = 'https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/upload';
```

## Step 6: Deploy Updated Website

```bash
# Sync the updated gallery.html to S3
cd "c:\Users\aday0\OneDrive\Dev\viaFiume_Laptop"
bash upload-to-s3.sh
```

## Testing

1. Open your website: https://viafiume.com/pages/gallery.html
2. Navigate to the June 2025 section
3. Click "Upload Photo"
4. Select an image (JPEG or HEIC)
5. Wait for the upload to complete
6. Page will refresh and show your uploaded image in the carousel

## Troubleshooting

### Lambda Function Errors
Check CloudWatch Logs:
```bash
aws logs tail /aws/lambda/GalleryUploadFunction --follow --profile viafiume
```

### API Gateway Issues
- Ensure CORS is properly configured
- Check that Lambda has permission to be invoked by API Gateway

### Update Lambda Function
If you need to update the Lambda code:
```bash
# Repackage
powershell Compress-Archive -Path index.js,node_modules,package.json -DestinationPath function.zip -Force

# Update function
aws lambda update-function-code \
  --function-name GalleryUploadFunction \
  --zip-file fileb://function.zip \
  --profile viafiume
```

## Cost Estimate

- Lambda: Free tier includes 1M requests/month and 400,000 GB-seconds compute time
- API Gateway: Free tier includes 1M API calls/month for 12 months
- S3: Storage costs only (minimal for images)
- CloudFront: Data transfer costs (minimal for cache invalidations)

Expected monthly cost: < $1 for typical usage
