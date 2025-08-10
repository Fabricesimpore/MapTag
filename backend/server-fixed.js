const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const path = require('path');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static file serving for uploaded images
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://maptag:password123@localhost:5432/maptag_bf'
});

// Test database connection
pool.connect((err, client, release) => {
    if (err) {
        console.error('Error acquiring client:', err.stack);
        return;
    }
    console.log('✅ Connected to PostgreSQL database');
    release();
});

// Make pool available to routes
app.locals.pool = pool;

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Simple addresses endpoints to start with
app.get('/api/addresses', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT id, code, latitude, longitude, place_name, category, 
                   verification_status, confidence_score, created_at 
            FROM addresses 
            ORDER BY created_at DESC 
            LIMIT 20
        `);
        
        res.json({
            success: true,
            addresses: result.rows,
            count: result.rows.length
        });
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

app.get('/api/addresses/:code', async (req, res) => {
    try {
        const { code } = req.params;
        const result = await pool.query(
            'SELECT * FROM addresses WHERE code = $1', 
            [code]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ 
                error: 'Address not found' 
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

// Basic address creation endpoint
app.post('/api/addresses', express.json(), async (req, res) => {
    try {
        const { latitude, longitude, placeName, category } = req.body;
        
        if (!latitude || !longitude || !placeName) {
            return res.status(400).json({
                error: 'Missing required fields: latitude, longitude, placeName'
            });
        }
        
        // Generate simple code for testing
        const code = `BF-TEST-${Date.now().toString().slice(-6)}`;
        
        const result = await pool.query(`
            INSERT INTO addresses (code, latitude, longitude, place_name, category)
            VALUES ($1, $2, $3, $4, $5) 
            RETURNING *
        `, [code, latitude, longitude, placeName, category || 'Autre']);
        
        res.status(201).json({
            success: true,
            address: result.rows[0],
            message: 'Address created successfully'
        });
        
    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({ 
            error: 'Database error',
            message: error.message 
        });
    }
});

// Verification statistics endpoint
app.get('/api/verification/stats', async (req, res) => {
    try {
        const statsQuery = `
            SELECT 
                COUNT(CASE WHEN verification_status = 'verified' THEN 1 END) as verified_count,
                COUNT(CASE WHEN verification_status = 'pending' THEN 1 END) as pending_count,
                COUNT(CASE WHEN verification_status = 'rejected' THEN 1 END) as rejected_count,
                COUNT(*) as total_addresses,
                AVG(confidence_score) as avg_confidence_score
            FROM addresses
        `;
        
        const result = await pool.query(statsQuery);
        const stats = result.rows[0];
        
        res.json({
            success: true,
            statistics: {
                verified: parseInt(stats.verified_count),
                pending: parseInt(stats.pending_count),
                rejected: parseInt(stats.rejected_count),
                total: parseInt(stats.total_addresses),
                avg_confidence: parseFloat(stats.avg_confidence_score) || 0
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
    res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 MapTag BF Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🏠 Addresses API: http://localhost:${PORT}/api/addresses`);
    console.log(`📈 Statistics: http://localhost:${PORT}/api/verification/stats`);
});