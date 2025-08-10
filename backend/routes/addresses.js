const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const QRCode = require('qrcode');
const path = require('path');
const fs = require('fs');
const { generateAddressCode, validateAddressCode } = require('../utils/addressGenerator');
const { checkForDuplicatesAdvanced, reportDuplicate } = require('../utils/duplicateDetection');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        const uploadPath = path.join(__dirname, '../uploads');
        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath, { recursive: true });
        }
        cb(null, uploadPath);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'temp-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    },
    fileFilter: function (req, file, cb) {
        if (!file.mimetype.startsWith('image/')) {
            return cb(new Error('Only image files are allowed'));
        }
        cb(null, true);
    }
});

/**
 * POST /api/addresses - Create new address
 */
router.post('/', upload.single('photo'), async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { latitude, longitude, placeName, category } = req.body;
        
        // Validate required fields
        if (!latitude || !longitude || !placeName) {
            return res.status(400).json({
                error: 'Missing required fields: latitude, longitude, placeName'
            });
        }
        
        const lat = parseFloat(latitude);
        const lon = parseFloat(longitude);
        
        // Check for NaN values (invalid number conversion)
        if (isNaN(lat) || isNaN(lon)) {
            return res.status(400).json({
                error: 'Invalid coordinates: latitude and longitude must be valid numbers'
            });
        }
        
        // Validate coordinate ranges
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            return res.status(400).json({
                error: 'Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180'
            });
        }
        
        // Validate Burkina Faso boundaries (approximate)
        if (lat < 9.4 || lat > 15.1 || lon < -5.6 || lon > 2.5) {
            return res.status(400).json({
                error: 'Coordinates are outside Burkina Faso boundaries'
            });
        }
        
        // Check for duplicates using advanced detection
        const duplicates = await checkForDuplicatesAdvanced(
            pool, lat, lon, placeName, category || 'Other'
        );
        
        const likelyDuplicates = duplicates.filter(d => d.is_likely_duplicate);
        
        if (likelyDuplicates.length > 0) {
            return res.status(409).json({
                error: 'Potential duplicate detected',
                duplicates: likelyDuplicates,
                suggestion: 'Please verify this is a new location or select an existing address'
            });
        }
        
        // Generate unique address code
        let code;
        let isUnique = false;
        let attempts = 0;
        
        while (!isUnique && attempts < 5) {
            code = generateAddressCode(lat, lon, placeName);
            const existingCode = await pool.query(
                'SELECT id FROM addresses WHERE code = $1', 
                [code]
            );
            isUnique = existingCode.rows.length === 0;
            attempts++;
        }
        
        if (!isUnique) {
            return res.status(500).json({
                error: 'Unable to generate unique address code. Please try again.'
            });
        }
        
        // Process and save photo if provided
        let photoUrl = null;
        if (req.file) {
            try {
                const filename = `${code}_${Date.now()}.jpg`;
                const finalPath = path.join(__dirname, '../uploads', filename);
                
                await sharp(req.file.path)
                    .resize(800, 600, { fit: 'inside', withoutEnlargement: true })
                    .jpeg({ quality: 80 })
                    .toFile(finalPath);
                
                photoUrl = `/uploads/${filename}`;
                
                // Remove temp file
                fs.unlinkSync(req.file.path);
            } catch (photoError) {
                console.error('Photo processing error:', photoError);
                // Continue without photo if processing fails
                if (req.file && fs.existsSync(req.file.path)) {
                    fs.unlinkSync(req.file.path);
                }
            }
        }
        
        // Insert into database
        const insertQuery = `
            INSERT INTO addresses (code, latitude, longitude, place_name, category, building_photo_url)
            VALUES ($1, $2, $3, $4, $5, $6) 
            RETURNING *
        `;
        
        const result = await pool.query(insertQuery, [
            code, lat, lon, placeName, category || 'Other', photoUrl
        ]);
        
        const address = result.rows[0];
        
        // Generate QR code
        const shareUrl = `https://maptag.bf/${code}`;
        let qrCodeUrl = null;
        
        try {
            qrCodeUrl = await QRCode.toDataURL(shareUrl);
        } catch (qrError) {
            console.error('QR code generation error:', qrError);
        }
        
        // Add to verification queue for AI processing
        await pool.query(
            `INSERT INTO verification_queue (address_id, verification_type, ai_confidence)
             VALUES ($1, 'photo_match', 0)`,
            [address.id]
        );
        
        res.status(201).json({
            success: true,
            address: {
                id: address.id,
                code: address.code,
                latitude: address.latitude,
                longitude: address.longitude,
                place_name: address.place_name,
                category: address.category,
                building_photo_url: address.building_photo_url,
                verification_status: address.verification_status,
                created_at: address.created_at
            },
            qrCode: qrCodeUrl,
            shareUrl: shareUrl,
            shortUrl: `https://maptag.bf/s/${code.split('-').pop()}`
        });
        
    } catch (error) {
        console.error('Error creating address:', error);
        
        // Clean up uploaded file on error
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        
        res.status(500).json({ 
            error: 'Internal server error',
            message: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * GET /api/addresses/:code - Get address by code
 */
router.get('/:code', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { code } = req.params;
        
        if (!validateAddressCode(code)) {
            return res.status(400).json({
                error: 'Invalid address code format'
            });
        }
        
        const result = await pool.query(
            'SELECT * FROM addresses WHERE code = $1', 
            [code]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ 
                error: 'Address not found' 
            });
        }
        
        const address = result.rows[0];
        
        res.json({
            id: address.id,
            code: address.code,
            latitude: parseFloat(address.latitude),
            longitude: parseFloat(address.longitude),
            place_name: address.place_name,
            category: address.category,
            building_photo_url: address.building_photo_url,
            verification_status: address.verification_status,
            confidence_score: address.confidence_score,
            created_at: address.created_at,
            updated_at: address.updated_at
        });
        
    } catch (error) {
        console.error('Error retrieving address:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * GET /api/addresses - Search addresses (with pagination)
 */
router.get('/', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { 
            search, 
            category, 
            lat, 
            lon, 
            radius = 1000, 
            page = 1, 
            limit = 20 
        } = req.query;
        
        let query = 'SELECT * FROM addresses WHERE 1=1';
        const queryParams = [];
        let paramIndex = 1;
        
        // Text search
        if (search) {
            query += ` AND place_name ILIKE $${paramIndex}`;
            queryParams.push(`%${search}%`);
            paramIndex++;
        }
        
        // Category filter
        if (category) {
            query += ` AND category = $${paramIndex}`;
            queryParams.push(category);
            paramIndex++;
        }
        
        // Geographic search
        if (lat && lon) {
            query += ` AND ST_DWithin(
                geom, 
                ST_SetSRID(ST_MakePoint($${paramIndex}, $${paramIndex + 1}), 4326)::geography, 
                $${paramIndex + 2}
            )`;
            queryParams.push(parseFloat(lon), parseFloat(lat), parseFloat(radius));
            paramIndex += 3;
        }
        
        // Pagination
        const offset = (parseInt(page) - 1) * parseInt(limit);
        query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        queryParams.push(parseInt(limit), offset);
        
        const result = await pool.query(query, queryParams);
        
        // Get total count for pagination
        let countQuery = 'SELECT COUNT(*) FROM addresses WHERE 1=1';
        const countParams = queryParams.slice(0, -2); // Remove limit and offset
        
        if (search) countQuery += ` AND place_name ILIKE $1`;
        if (category) countQuery += ` AND category = $${search ? 2 : 1}`;
        if (lat && lon) {
            const geoParamIndex = (search ? 1 : 0) + (category ? 1 : 0) + 1;
            countQuery += ` AND ST_DWithin(
                geom, 
                ST_SetSRID(ST_MakePoint($${geoParamIndex}, $${geoParamIndex + 1}), 4326)::geography, 
                $${geoParamIndex + 2}
            )`;
        }
        
        const countResult = await pool.query(countQuery, countParams);
        const totalCount = parseInt(countResult.rows[0].count);
        const totalPages = Math.ceil(totalCount / parseInt(limit));
        
        res.json({
            addresses: result.rows.map(address => ({
                id: address.id,
                code: address.code,
                latitude: parseFloat(address.latitude),
                longitude: parseFloat(address.longitude),
                place_name: address.place_name,
                category: address.category,
                verification_status: address.verification_status,
                confidence_score: address.confidence_score,
                created_at: address.created_at
            })),
            pagination: {
                current_page: parseInt(page),
                total_pages: totalPages,
                total_count: totalCount,
                has_next: parseInt(page) < totalPages,
                has_prev: parseInt(page) > 1
            }
        });
        
    } catch (error) {
        console.error('Error searching addresses:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * POST /api/addresses/:code/report-duplicate - Report a duplicate
 */
router.post('/:code/report-duplicate', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { code } = req.params;
        const { duplicate_code, reason } = req.body;
        
        if (!duplicate_code) {
            return res.status(400).json({
                error: 'duplicate_code is required'
            });
        }
        
        // Get both addresses
        const addressResult = await pool.query(
            'SELECT id, latitude, longitude FROM addresses WHERE code = $1', 
            [code]
        );
        
        const duplicateResult = await pool.query(
            'SELECT id, latitude, longitude FROM addresses WHERE code = $1', 
            [duplicate_code]
        );
        
        if (addressResult.rows.length === 0 || duplicateResult.rows.length === 0) {
            return res.status(404).json({
                error: 'One or both addresses not found'
            });
        }
        
        const address = addressResult.rows[0];
        const duplicate = duplicateResult.rows[0];
        
        // Calculate distance between addresses
        const geolib = require('geolib');
        const distance = geolib.getDistance(
            { latitude: address.latitude, longitude: address.longitude },
            { latitude: duplicate.latitude, longitude: duplicate.longitude }
        );
        
        await reportDuplicate(pool, address.id, duplicate.id, distance);
        
        res.json({
            success: true,
            message: 'Duplicate report submitted successfully'
        });
        
    } catch (error) {
        console.error('Error reporting duplicate:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

module.exports = router;