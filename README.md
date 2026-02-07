# Via Fiume

Static website for viafiume.com - A vacation rental property website hosted on AWS S3.

## Overview

This repository contains the source files for the Via Fiume vacation rental website. The site is a static HTML/CSS website hosted on Amazon S3 and served through CloudFront.

## Structure

```
.
├── index.html          # Main homepage
├── error.html          # Custom 404 error page
├── css/                # Stylesheets
│   └── style.css
├── images/             # Image assets
├── pages/              # Additional pages
├── doc/                # Guest guides and documentation
│   ├── GuidesACSplit.jpg
│   ├── GuidesACRemote.jpg
│   ├── GuidesKitchen.jpg
│   ├── GuidesLaundry.jpg
│   └── GuidesTrash.jpg
└── upload-to-s3.sh     # Deployment script
```

## Deployment

The website is deployed to AWS S3 using the included deployment script:

```bash
./upload-to-s3.sh
```

This script:
- Syncs all files to the S3 bucket `s3://viafiume.com`
- Excludes shell scripts and system files
- Deletes files from S3 that don't exist locally
- Uses the `viafiume` AWS CLI profile

## Local Development

To work with this site locally:

1. Clone the repository
2. Open `index.html` in a web browser
3. Make your changes
4. Deploy using the upload script when ready

## AWS Configuration

The site requires AWS CLI configured with the `viafiume` profile. See `~/.aws/config` and `~/.aws/credentials` for setup.

## Live Site

Visit: [https://viafiume.com](https://viafiume.com)
