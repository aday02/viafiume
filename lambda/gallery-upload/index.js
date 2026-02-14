const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
const { CloudFrontClient, CreateInvalidationCommand } = require('@aws-sdk/client-cloudfront');
const sharp = require('sharp');

const s3 = new S3Client();
const cloudfront = new CloudFrontClient();

const BUCKET_NAME = 'viafiume.com';
const CLOUDFRONT_DISTRIBUTION_ID = 'E2OE2FPALKHHUZ';

exports.handler = async (event) => {
    try {
        // Parse the request body
        const body = JSON.parse(event.body);
        const fileData = Buffer.from(body.file, 'base64');
        const fileName = body.fileName;
        const galleryFolder = body.galleryFolder; // e.g., "2025-06"

        const fileExt = fileName.toLowerCase().split('.').pop();
        if (!['jpg', 'jpeg', 'png', 'gif', 'heic', 'heif'].includes(fileExt)) {
            return {
                statusCode: 400,
                headers: {
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Only JPEG, PNG, GIF, and HEIC files are supported.'
                })
            };
        }

        // Convert HEIC/HEIF to JPEG, pass other formats through
        let uploadData = fileData;
        let uploadExt = fileExt;
        let contentType;

        if (fileExt === 'heic' || fileExt === 'heif') {
            console.log('Converting HEIC to JPEG...');
            uploadData = await sharp(fileData).jpeg({ quality: 90 }).toBuffer();
            uploadExt = 'jpg';
            contentType = 'image/jpeg';
        } else {
            const contentTypeMap = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'gif': 'image/gif'
            };
            contentType = contentTypeMap[fileExt] || 'image/jpeg';
        }

        // Generate a timestamp-based filename to avoid collisions
        const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '');
        const baseName = fileName.replace(/\.[^.]+$/, '');
        const s3Key = `images/gallery/${galleryFolder}/${timestamp}_${baseName}.${uploadExt}`;

        // Upload to S3
        console.log(`Uploading to S3: ${s3Key}`);
        await s3.send(new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: s3Key,
            Body: uploadData,
            ContentType: contentType
        }));

        // Update the gallery HTML
        await updateGalleryHTML(galleryFolder, s3Key);

        // Invalidate CloudFront cache
        console.log('Invalidating CloudFront cache...');
        await cloudfront.send(new CreateInvalidationCommand({
            DistributionId: CLOUDFRONT_DISTRIBUTION_ID,
            InvalidationBatch: {
                CallerReference: `gallery-upload-${Date.now()}`,
                Paths: {
                    Quantity: 1,
                    Items: ['/pages/gallery.html']
                }
            }
        }));

        return {
            statusCode: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            body: JSON.stringify({
                message: 'Image uploaded successfully',
                imageUrl: `https://viafiume.com/${s3Key}`
            })
        };

    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            headers: {
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: error.message
            })
        };
    }
};

async function updateGalleryHTML(galleryFolder, newImageKey) {
    try {
        // Download current gallery.html
        const htmlData = await s3.send(new GetObjectCommand({
            Bucket: BUCKET_NAME,
            Key: 'pages/gallery.html'
        }));

        const htmlContent = await htmlData.Body.transformToString('utf-8');
        let updatedHtml = htmlContent;

        // Determine which carousel to update based on gallery folder
        let carouselId, sectionTitle;
        if (galleryFolder === '2025-06') {
            carouselId = 'jun2025';
            sectionTitle = 'June 2025';
        } else if (galleryFolder === '2025-10') {
            carouselId = 'oct2025';
            sectionTitle = 'October 2025';
        } else if (galleryFolder === '2026-02') {
            carouselId = 'feb2026';
            sectionTitle = 'February 2026';
        }

        // Extract date from filename for alt text
        const altText = `Pescara - ${sectionTitle}`;

        // Create new carousel slide HTML
        const newSlide = `                            <div class="carousel-slide">
                                <img src="../${newImageKey}" alt="${altText}">
                            </div>`;

        // Find the carousel slides container and add new slide
        const slidesEndPattern = new RegExp(`(id="${carouselId}-slides">\\s*(?:<!--[^>]*>\\s*)?)([\\s\\S]*?)(\\s*</div>\\s*<!--.*?Next Button)`, 'm');

        if (slidesEndPattern.test(updatedHtml)) {
            updatedHtml = updatedHtml.replace(slidesEndPattern, (match, opening, slides, closing) => {
                // If there are no slides yet, add the first one with active class
                if (slides.trim() === '' || slides.trim() === '<!-- Photos will be dynamically added here -->') {
                    const firstSlide = `                            <div class="carousel-slide active">
                                <img src="../${newImageKey}" alt="${altText}">
                            </div>`;
                    return `${opening}\n${firstSlide}\n                        ${closing}`;
                } else {
                    return `${opening}${slides}\n${newSlide}\n                        ${closing}`;
                }
            });
        }

        // Update the photo counter if it exists
        const counterPattern = new RegExp(`(<div class="photo-counter" id="${carouselId}-counter">)(\\d+) / (\\d+)(</div>)`, 'g');
        updatedHtml = updatedHtml.replace(counterPattern, (match, prefix, current, total, suffix) => {
            const newTotal = parseInt(total) + 1;
            return `${prefix}1 / ${newTotal}${suffix}`;
        });

        // Upload updated HTML back to S3
        await s3.send(new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: 'pages/gallery.html',
            Body: updatedHtml,
            ContentType: 'text/html'
        }));

        console.log('Gallery HTML updated successfully');

    } catch (error) {
        console.error('Error updating gallery HTML:', error);
        throw error;
    }
}
