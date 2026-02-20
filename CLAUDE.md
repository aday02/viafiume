# Project: viaFiume.com

A static website hosted on AWS S3 + CloudFront for sharing details about a family apartment in Pescara, Italy with friends and family. It highlights local food, activities, and provides practical info for guests.

## Architecture

- **Static site** served from S3 via CloudFront
- **Lambda function** (`gallery-upload`) handles photo uploads via API Gateway
- **S3 Bucket:** `viafiume.com`
- **CloudFront Distribution:** `E2OE2FPALKHHUZ`
- **API Gateway endpoint:** `https://sktkk4pr57.execute-api.us-west-2.amazonaws.com/prod/upload`
- **API Gateway** is public/unauthenticated (acceptable for personal family site)

## Key Files

- `pages/gallery.html` — Photo gallery with client-side upload (compresses via canvas: max 2000px, JPEG quality 0.8 to stay under API Gateway 10MB limit)
- `pages/keys.html` — PIN-protected key pickup instructions (AES-256-GCM encrypted with PBKDF2). PIN is not stored in this file — use `encrypt-content.html` to re-encrypt.
- `encrypt-content.html` — Local-only encryption tool for keys.html content. In `.gitignore`, must NEVER be deployed to S3.
- `lambda/gallery-upload/index.js` — Lambda using AWS SDK v3, Sharp for HEIC-to-JPEG conversion, Node.js 22.x runtime
- `lambda/gallery-upload/package.json` — Dependencies: `@aws-sdk/client-s3`, `@aws-sdk/client-cloudfront`, `sharp`
- `images/Keys/` — Key instruction photos (building-door.jpg, lockbox-closed.jpg, lockbox-open.jpg, apartment-key.jpg [actually the hallway skeleton key], mailbox.jpg, hallway-painting.jpg)

## Lambda Deployment

- Install npm packages with `--os=linux --cpu=x64 --libc=glibc` for Sharp to work on Lambda
- Package as zip using PowerShell `Compress-Archive` (no `zip` on Windows)
- Deploy with `aws lambda update-function-code`
- Use `MSYS_NO_PATHCONV=1` prefix for AWS CLI commands in Git Bash to prevent path conversion

## .gitignore Excludes

- `images/gallery/` — stored in S3 only; Lambda updates gallery.html in S3 with new photos
- `encrypt-content.html` — security; not for deployment
- `.claude/settings.local.json`
- `lambda/gallery-upload/trust-policy.json`

## Environment

- Windows 11, Git Bash
- Node.js installed via winget (may need `export PATH="$PATH:/c/Program Files/nodejs"` in bash)
- AWS CLI configured
- GitHub CLI (`gh`) available

## Important Notes

- The S3 version of `gallery.html` may differ from the local version because the Lambda appends new photo entries directly to S3.
- `apartment-key.jpg` is misleadingly named — it is actually the long skeleton key for the hallway security door, not the apartment key.
