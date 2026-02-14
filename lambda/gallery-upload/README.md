# Gallery Image Upload Feature

This feature allows users to upload images directly from the website to your S3 bucket and have them automatically appear in the gallery carousel.

## Features

- 📤 Upload images directly from the webpage
- 🔄 Automatic HEIC to JPEG conversion
- 🖼️ Automatic carousel updates
- ⚡ CloudFront cache invalidation
- 📱 Mobile-friendly upload interface

## How It Works

1. User clicks "Upload Photo" on the gallery page
2. Selects an image (JPEG, PNG, or HEIC format)
3. Image is sent to AWS Lambda via API Gateway
4. Lambda processes the image:
   - Converts HEIC to JPEG if needed
   - Uploads to S3 in the appropriate gallery folder
   - Updates the gallery.html file with the new image
   - Invalidates CloudFront cache
5. Page refreshes automatically to show the new image

## Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
cd lambda/gallery-upload
bash deploy.sh
```

This will:
- Install dependencies
- Create IAM role with necessary permissions
- Deploy Lambda function
- Set up API Gateway with CORS
- Output your API endpoint

### Option 2: Manual Deployment

Follow the detailed instructions in [DEPLOYMENT.md](DEPLOYMENT.md)

## After Deployment

1. Copy the API Gateway endpoint from the deployment output
2. Update `pages/gallery.html`:
   ```javascript
   const UPLOAD_API_ENDPOINT = 'https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/upload';
   ```
3. Sync to S3:
   ```bash
   bash upload-to-s3.sh
   ```

## Testing

1. Visit https://viafiume.com/pages/gallery.html
2. Scroll to "June 2025 Visit" section
3. Click "Upload Photo"
4. Select an image
5. Wait for upload confirmation
6. Page will refresh showing your new image

## File Structure

```
lambda/gallery-upload/
├── index.js           # Lambda function code
├── package.json       # Node.js dependencies
├── deploy.sh          # Automated deployment script
├── DEPLOYMENT.md      # Detailed deployment guide
└── README.md          # This file
```

## Architecture

```
User Browser
    ↓
[gallery.html] → Upload Photo
    ↓
[API Gateway] → /upload endpoint
    ↓
[Lambda Function]
    ├── Convert HEIC → JPEG (if needed)
    ├── Upload to S3
    ├── Update gallery.html
    └── Invalidate CloudFront cache
    ↓
[S3 Bucket: viafiume.com]
    └── images/gallery/2025-06/
```

## Supported Image Formats

- JPEG (.jpg, .jpeg)
- PNG (.png)
- HEIC (.heic) - automatically converted to JPEG
- GIF (.gif)
- WebP (.webp)

## Costs

Expected monthly costs for typical usage (< 100 uploads/month):
- Lambda: Free (within free tier)
- API Gateway: Free (within free tier)
- S3 Storage: ~$0.01 per GB
- CloudFront: Minimal (cache invalidations)

**Total: < $1/month**

## Troubleshooting

### Upload fails with CORS error
- Check that API Gateway has CORS properly configured
- Ensure OPTIONS method is set up
- Verify API endpoint URL is correct in gallery.html

### Image doesn't appear after upload
- Check CloudWatch Logs: `aws logs tail /aws/lambda/GalleryUploadFunction --follow --profile viafiume`
- Verify CloudFront invalidation completed
- Hard refresh the page (Ctrl+F5)

### HEIC conversion fails
- Ensure Lambda has sufficient memory (512MB recommended)
- Check that Sharp library is properly installed
- Verify the HEIC file is not corrupted

## Security Considerations

- Currently allows uploads from any origin (CORS: *)
- No file size limit on client side (Lambda has 6MB payload limit)
- No authentication required

**For production use, consider:**
- Adding authentication (Cognito, API keys)
- Implementing file size validation
- Adding rate limiting
- Restricting CORS to your domain only

## Future Enhancements

- [ ] Add image compression/optimization
- [ ] Support multiple file uploads at once
- [ ] Add progress bar for uploads
- [ ] Implement drag-and-drop interface
- [ ] Add authentication for uploads
- [ ] Create admin panel to manage uploads
- [ ] Add ability to delete/reorder images
