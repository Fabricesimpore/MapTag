const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL || 'postgresql://maptag:password123@localhost:5432/maptag_bf'
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

// Simple test endpoints without external routes first
app.get('/api/test', (req, res) => {
    res.json({ message: 'API is working!' });
});

// Test database connection
app.get('/api/db-test', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW() as time');
        res.json({ 
            database: 'connected',
            server_time: result.rows[0].time 
        });
    } catch (error) {
        res.status(500).json({ 
            database: 'error',
            error: error.message 
        });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`MapTag BF Test Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`DB test: http://localhost:${PORT}/api/db-test`);
});

// Test database connection on startup
pool.connect((err, client, release) => {
    if (err) {
        console.error('Database connection error:', err.stack);
        return;
    }
    console.log('✅ Connected to PostgreSQL database');
    release();
});