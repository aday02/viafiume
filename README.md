# Via Fiume

Website for viafiume.com - Sharing our apartment in Pescara, Italy with friends and family. Highlights local dining, activities, and what to expect when you visit.

## Overview

This repository contains the source files for the Via Fiume website. The site is a static HTML/CSS website hosted on Amazon S3 and served through CloudFront. It includes pages covering local restaurants, things to do, getting here, and a photo gallery with upload functionality powered by AWS Lambda.

## Structure

```
.
├── index.html              # Main homepage
├── error.html              # Custom 404 error page
├── css/                    # Stylesheets
│   └── style.css
├── images/                 # Image assets
│   └── gallery/            # Gallery photos organized by visit date
│       ├── 2025-06/        # June 2025
│       ├── 2025-10/        # October 2025
│       └── 2026-02/        # February 2026
├── pages/                  # Additional pages
│   ├── gallery.html        # Photo gallery with upload & carousels
│   ├── getting-here.html
│   ├── restaurants.html
│   ├── things-to-do.html
│   └── availability.html
├── doc/                    # Guest guides and documentation
├── lambda/                 # AWS Lambda functions
│   └── gallery-upload/     # Gallery photo upload function
│       ├── index.js        # Lambda handler (Node.js 22, AWS SDK v3)
│       ├── package.json    # Dependencies (Sharp, AWS SDK v3)
│       └── deploy.sh       # Deployment script
└── upload-to-s3.sh         # Site deployment script
```

## Prerequisites

- **AWS CLI** configured with the `viafiume` profile
- **Node.js** (v20+) and npm - required for Lambda development
  ```bash
  winget install OpenJS.NodeJS.LTS
  ```

## Deployment

### Static Site

Sync all site files to S3:

```bash
./upload-to-s3.sh
```

This script syncs files to `s3://viafiume.com`, excludes shell scripts and system files, and deletes stale files from S3.

### Lambda Function

The gallery upload Lambda requires packaging with its dependencies before deploying:

```bash
cd lambda/gallery-upload
npm install --os=linux --cpu=x64
```

Then package and deploy:

```bash
# Package (exclude node_modules docs to keep it small)
powershell -Command "Compress-Archive -Path index.js, node_modules -DestinationPath function.zip -Force"

# Deploy
aws lambda update-function-code \
  --function-name GalleryUploadFunction \
  --zip-file fileb://function.zip \
  --profile viafiume --region us-west-2
```

Or use the automated script:

```bash
bash deploy.sh
```

See [lambda/gallery-upload/DEPLOYMENT.md](lambda/gallery-upload/DEPLOYMENT.md) for full setup instructions including IAM roles and API Gateway configuration.

## Gallery Upload Feature

Users can upload photos directly from the gallery page. The upload flow:

1. User clicks "Upload Photo" on any gallery section
2. Selects an image (JPEG, PNG, GIF, or HEIC)
3. Image is sent to Lambda via API Gateway
4. Lambda converts HEIC to JPEG if needed (via Sharp), uploads to S3, updates the gallery HTML carousel, and invalidates the CloudFront cache
5. Page refreshes to show the new image

### AWS Resources

| Resource | Name / ID | Region |
|---|---|---|
| Lambda Function | `GalleryUploadFunction` (Node.js 22.x) | us-west-2 |
| API Gateway | `sktkk4pr57` | us-west-2 |
| IAM Role | `GalleryUploadLambdaRole` | - |
| S3 Bucket | `viafiume.com` | us-west-2 |
| CloudFront | `E2OE2FPALKHHUZ` | Global |

## Local Development

1. Clone the repository
2. Install Node.js dependencies for Lambda development:
   ```bash
   cd lambda/gallery-upload
   npm install
   ```
3. Open `index.html` in a browser for site changes
4. Deploy using the appropriate script when ready

**Note:** Gallery uploads cannot be tested locally due to browser CORS restrictions with `file://` URLs. Test uploads from the live site.

## Live Site

Visit: [https://viafiume.com](https://viafiume.com)
