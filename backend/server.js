// MapTag BF - Production-ready minimal server
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

console.log('🚀 Starting MapTag BF Server...');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://maptag:password123@localhost:5432/maptag_bf'
});

// Make pool available to all routes
app.locals.pool = pool;

// Test database connection
pool.connect()
    .then(client => {
        console.log('✅ Database connected successfully');
        client.release();
    })
    .catch(err => {
        console.error('❌ Database connection error:', err.message);
    });

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    });
});

// API Test endpoint
app.get('/api/test', (req, res) => {
    res.json({ 
        message: 'MapTag BF API is working!',
        endpoints: [
            'GET /api/addresses - List all addresses',
            'POST /api/addresses - Create new address',
            'GET /api/addresses/{code} - Get specific address',
            'GET /api/verification/stats - Get verification statistics'
        ]
    });
});

// Get all addresses
app.get('/api/addresses', async (req, res) => {
    try {
        const { search, category, limit = 20, page = 1 } = req.query;
        let query = `
            SELECT id, code, latitude, longitude, place_name, category, 
                   verification_status, confidence_score, created_at 
            FROM addresses 
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;

        if (search) {
            query += ` AND (place_name ILIKE $${paramIndex} OR code ILIKE $${paramIndex})`;
            params.push(`%${search}%`);
            paramIndex++;
        }

        if (category) {
            query += ` AND category = $${paramIndex}`;
            params.push(category);
            paramIndex++;
        }

        query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(parseInt(limit));
        params.push((parseInt(page) - 1) * parseInt(limit));

        const result = await pool.query(query, params);
        
        // Get total count for pagination
        let countQuery = 'SELECT COUNT(*) FROM addresses WHERE 1=1';
        const countParams = params.slice(0, -2); // Remove limit and offset
        
        if (search) countQuery += ` AND (place_name ILIKE $1 OR code ILIKE $1)`;
        if (category) countQuery += ` AND category = $${search ? 2 : 1}`;
        
        const countResult = await pool.query(countQuery, countParams);
        const totalCount = parseInt(countResult.rows[0].count);
        
        res.json({
            success: true,
            addresses: result.rows,
            pagination: {
                current_page: parseInt(page),
                total_count: totalCount,
                total_pages: Math.ceil(totalCount / parseInt(limit)),
                has_next: parseInt(page) * parseInt(limit) < totalCount
            }
        });
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

// Get address by code
app.get('/api/addresses/:code', async (req, res) => {
    try {
        const { code } = req.params;
        const result = await pool.query(
            'SELECT * FROM addresses WHERE code = $1', 
            [code]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ 
                error: 'Address not found',
                code: code
            });
        }
        
        res.json({
            success: true,
            address: result.rows[0]
        });
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

// Create new address (simplified)
app.post('/api/addresses', async (req, res) => {
    try {
        const { latitude, longitude, placeName, category } = req.body;
        
        // Validation
        if (!latitude || !longitude || !placeName) {
            return res.status(400).json({
                error: 'Missing required fields',
                required: ['latitude', 'longitude', 'placeName']
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

        // Generate address code (simplified for MVP)
        const cityCode = determineCityCode(lat, lon);
        const gridCode = Math.floor(Math.random() * 9999).toString().padStart(4, '0');
        const uniqueCode = Math.random().toString(36).substring(2, 6).toUpperCase();
        const code = `BF-${cityCode}-${gridCode}-${uniqueCode}`;

        // Insert into database
        const result = await pool.query(`
            INSERT INTO addresses (code, latitude, longitude, place_name, category, verification_status, confidence_score)
            VALUES ($1, $2, $3, $4, $5, $6, $7) 
            RETURNING *
        `, [code, lat, lon, placeName, category || 'Autre', 'pending', 0]);
        
        res.status(201).json({
            success: true,
            address: result.rows[0],
            message: 'Address created successfully',
            qr_url: `https://maptag.bf/${code}`,
            share_url: `https://maptag.bf/${code}`
        });
        
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

// City code determination (from original plan)
function determineCityCode(lat, lon) {
    if (lat > 12.2 && lat < 12.5 && lon > -1.7 && lon < -1.3) return 'OUA'; // Ouagadougou
    if (lat > 11.0 && lat < 11.3 && lon > -4.5 && lon < -4.0) return 'BOB'; // Bobo-Dioulasso
    if (lat > 12.1 && lat < 12.4 && lon > -2.5 && lon < -2.2) return 'KOU'; // Koudougou
    return 'OTH'; // Other
}

// Verification statistics
app.get('/api/verification/stats', async (req, res) => {
    try {
        const statsQuery = `
            SELECT 
                COUNT(CASE WHEN verification_status = 'verified' THEN 1 END) as verified_count,
                COUNT(CASE WHEN verification_status = 'pending' THEN 1 END) as pending_count,
                COUNT(CASE WHEN verification_status = 'rejected' THEN 1 END) as rejected_count,
                COUNT(CASE WHEN verification_status = 'flagged' THEN 1 END) as flagged_count,
                COUNT(*) as total_addresses,
                AVG(confidence_score) as avg_confidence_score,
                COUNT(CASE WHEN category = 'Résidence' THEN 1 END) as residence_count,
                COUNT(CASE WHEN category = 'Commerce' THEN 1 END) as commerce_count
            FROM addresses
        `;
        
        const result = await pool.query(statsQuery);
        const stats = result.rows[0];
        
        res.json({
            success: true,
            statistics: {
                verification: {
                    verified: parseInt(stats.verified_count),
                    pending: parseInt(stats.pending_count),
                    rejected: parseInt(stats.rejected_count),
                    flagged: parseInt(stats.flagged_count)
                },
                total_addresses: parseInt(stats.total_addresses),
                avg_confidence: parseFloat(stats.avg_confidence_score) || 0,
                categories: {
                    residence: parseInt(stats.residence_count),
                    commerce: parseInt(stats.commerce_count)
                },
                verification_rate: stats.total_addresses > 0 
                    ? ((parseInt(stats.verified_count) / parseInt(stats.total_addresses)) * 100).toFixed(1)
                    : 0
            }
        });
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Server error:', err.stack);
    res.status(500).json({ 
        error: 'Something went wrong!',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ 
        error: 'Route not found',
        available_routes: [
            'GET /health',
            'GET /api/test', 
            'GET /api/addresses',
            'POST /api/addresses',
            'GET /api/addresses/{code}',
            'GET /api/verification/stats'
        ]
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log('');
    console.log('🎉 MapTag BF Server Started Successfully!');
    console.log('');
    console.log(`🌐 Server URL: http://localhost:${PORT}`);
    console.log(`💚 Health Check: http://localhost:${PORT}/health`);
    console.log(`🏠 Addresses API: http://localhost:${PORT}/api/addresses`);
    console.log(`📊 Statistics: http://localhost:${PORT}/api/verification/stats`);
    console.log(`🔧 API Test: http://localhost:${PORT}/api/test`);
    console.log('');
    console.log('Ready to serve MapTag BF requests! 🇧🇫');
});