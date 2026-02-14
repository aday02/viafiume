#!/bin/bash

# Gallery Upload Lambda Deployment Script
# This script automates the deployment of the Lambda function and API Gateway

set -e  # Exit on error

PROFILE="viafiume"
REGION="us-east-1"
FUNCTION_NAME="GalleryUploadFunction"
ROLE_NAME="GalleryUploadLambdaRole"
API_NAME="GalleryUploadAPI"

echo "🚀 Starting deployment..."

# Get AWS Account ID
echo "📋 Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
echo "Account ID: $ACCOUNT_ID"

# Step 1: Install dependencies
echo ""
echo "📦 Installing Node.js dependencies..."
npm install

# Step 2: Create deployment package
echo ""
echo "📦 Creating deployment package..."
rm -f function.zip
zip -r function.zip index.js node_modules package.json -q
echo "✓ Deployment package created"

# Step 3: Check if IAM role exists, create if not
echo ""
echo "🔐 Setting up IAM role..."
if aws iam get-role --role-name $ROLE_NAME --profile $PROFILE 2>/dev/null; then
    echo "✓ IAM role already exists"
else
    echo "Creating IAM role..."

    # Create trust policy
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

    aws iam create-role \
      --role-name $ROLE_NAME \
      --assume-role-policy-document file://trust-policy.json \
      --profile $PROFILE

    aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
      --profile $PROFILE

    # Create custom policy
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
      --role-name $ROLE_NAME \
      --policy-name GalleryUploadPolicy \
      --policy-document file://lambda-permissions.json \
      --profile $PROFILE

    echo "✓ IAM role created, waiting 10 seconds for propagation..."
    sleep 10
fi

# Step 4: Create or update Lambda function
echo ""
echo "⚡ Setting up Lambda function..."
if aws lambda get-function --function-name $FUNCTION_NAME --profile $PROFILE 2>/dev/null; then
    echo "Updating existing Lambda function..."
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb://function.zip \
      --profile $PROFILE
    echo "✓ Lambda function updated"
else
    echo "Creating Lambda function..."
    aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime nodejs18.x \
      --handler index.handler \
      --role arn:aws:iam::${ACCOUNT_ID}:role/$ROLE_NAME \
      --zip-file fileb://function.zip \
      --timeout 30 \
      --memory-size 512 \
      --profile $PROFILE
    echo "✓ Lambda function created"
fi

# Step 5: Create API Gateway
echo ""
echo "🌐 Setting up API Gateway..."

# Check if API already exists
API_ID=$(aws apigateway get-rest-apis --profile $PROFILE --query "items[?name=='$API_NAME'].id" --output text)

if [ -z "$API_ID" ]; then
    echo "Creating new API Gateway..."

    API_ID=$(aws apigateway create-rest-api \
      --name "$API_NAME" \
      --description "API for uploading images to gallery" \
      --profile $PROFILE \
      --query 'id' \
      --output text)

    ROOT_ID=$(aws apigateway get-resources \
      --rest-api-id $API_ID \
      --profile $PROFILE \
      --query 'items[0].id' \
      --output text)

    RESOURCE_ID=$(aws apigateway create-resource \
      --rest-api-id $API_ID \
      --parent-id $ROOT_ID \
      --path-part upload \
      --profile $PROFILE \
      --query 'id' \
      --output text)

    # POST method
    aws apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method POST \
      --authorization-type NONE \
      --profile $PROFILE

    # Lambda integration
    aws apigateway put-integration \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method POST \
      --type AWS_PROXY \
      --integration-http-method POST \
      --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:${ACCOUNT_ID}:function:$FUNCTION_NAME/invocations \
      --profile $PROFILE

    # OPTIONS method for CORS
    aws apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method OPTIONS \
      --authorization-type NONE \
      --profile $PROFILE

    aws apigateway put-method-response \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method OPTIONS \
      --status-code 200 \
      --response-parameters '{"method.response.header.Access-Control-Allow-Headers": false,"method.response.header.Access-Control-Allow-Methods": false,"method.response.header.Access-Control-Allow-Origin": false}' \
      --profile $PROFILE

    aws apigateway put-integration \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method OPTIONS \
      --type MOCK \
      --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
      --profile $PROFILE

    aws apigateway put-integration-response \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method OPTIONS \
      --status-code 200 \
      --response-parameters '{"method.response.header.Access-Control-Allow-Headers": "'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods": "'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin": "'"'"'*'"'"'"}' \
      --profile $PROFILE

    # Grant Lambda invoke permission
    aws lambda add-permission \
      --function-name $FUNCTION_NAME \
      --statement-id apigateway-invoke \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "arn:aws:execute-api:$REGION:${ACCOUNT_ID}:${API_ID}/*/*" \
      --profile $PROFILE 2>/dev/null || true

    # Deploy API
    aws apigateway create-deployment \
      --rest-api-id $API_ID \
      --stage-name prod \
      --profile $PROFILE

    echo "✓ API Gateway created"
else
    echo "✓ API Gateway already exists (ID: $API_ID)"

    # Redeploy API
    aws apigateway create-deployment \
      --rest-api-id $API_ID \
      --stage-name prod \
      --profile $PROFILE
    echo "✓ API redeployed"
fi

# Step 6: Display the API endpoint
echo ""
echo "✅ Deployment complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 Your API Gateway endpoint:"
echo "   https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Update pages/gallery.html with this endpoint"
echo "2. Run: bash upload-to-s3.sh"
echo "3. Test the upload feature on your website"
echo ""

# Cleanup temporary files
rm -f trust-policy.json lambda-permissions.json function.zip

echo "🎉 All done!"
