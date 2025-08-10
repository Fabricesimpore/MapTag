const express = require('express');
const { getAddressesNeedingReview } = require('../utils/duplicateDetection');

const router = express.Router();

/**
 * GET /api/verification/queue - Get addresses pending verification
 */
router.get('/queue', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { status = 'pending', limit = 50 } = req.query;
        
        const query = `
            SELECT 
                vq.id as queue_id,
                vq.verification_type,
                vq.status,
                vq.ai_confidence,
                vq.created_at as queued_at,
                a.id,
                a.code,
                a.place_name,
                a.category,
                a.latitude,
                a.longitude,
                a.building_photo_url,
                a.verification_status
            FROM verification_queue vq
            JOIN addresses a ON vq.address_id = a.id
            WHERE vq.status = $1
            ORDER BY vq.created_at ASC
            LIMIT $2
        `;
        
        const result = await pool.query(query, [status, parseInt(limit)]);
        
        res.json({
            verification_queue: result.rows,
            count: result.rows.length
        });
        
    } catch (error) {
        console.error('Error getting verification queue:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * POST /api/verification/:queueId/process - Process verification manually
 */
router.post('/:queueId/process', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { queueId } = req.params;
        const { action, confidence_score, notes } = req.body; // action: 'approve', 'reject', 'flag'
        
        if (!['approve', 'reject', 'flag'].includes(action)) {
            return res.status(400).json({
                error: 'Invalid action. Must be approve, reject, or flag'
            });
        }
        
        await pool.query('BEGIN');
        
        // Get the verification queue item and associated address
        const queueResult = await pool.query(
            'SELECT address_id FROM verification_queue WHERE id = $1',
            [queueId]
        );
        
        if (queueResult.rows.length === 0) {
            await pool.query('ROLLBACK');
            return res.status(404).json({
                error: 'Verification queue item not found'
            });
        }
        
        const addressId = queueResult.rows[0].address_id;
        
        // Update verification queue
        await pool.query(
            `UPDATE verification_queue 
             SET status = 'completed', 
                 processed_at = CURRENT_TIMESTAMP,
                 ai_confidence = $2
             WHERE id = $1`,
            [queueId, confidence_score || 0]
        );
        
        // Update address verification status
        let verificationStatus;
        let newConfidenceScore;
        
        switch (action) {
            case 'approve':
                verificationStatus = 'verified';
                newConfidenceScore = confidence_score || 95;
                break;
            case 'reject':
                verificationStatus = 'rejected';
                newConfidenceScore = 0;
                break;
            case 'flag':
                verificationStatus = 'flagged';
                newConfidenceScore = confidence_score || 25;
                break;
        }
        
        await pool.query(
            `UPDATE addresses 
             SET verification_status = $1, 
                 confidence_score = $2,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $3`,
            [verificationStatus, newConfidenceScore, addressId]
        );
        
        await pool.query('COMMIT');
        
        res.json({
            success: true,
            message: `Address verification ${action}ed successfully`,
            verification_status: verificationStatus,
            confidence_score: newConfidenceScore
        });
        
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Error processing verification:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * GET /api/verification/stats - Get verification statistics
 */
router.get('/stats', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const statsQuery = `
            SELECT 
                COUNT(CASE WHEN verification_status = 'verified' THEN 1 END) as verified_count,
                COUNT(CASE WHEN verification_status = 'pending' THEN 1 END) as pending_count,
                COUNT(CASE WHEN verification_status = 'rejected' THEN 1 END) as rejected_count,
                COUNT(CASE WHEN verification_status = 'flagged' THEN 1 END) as flagged_count,
                COUNT(*) as total_addresses,
                AVG(confidence_score) as avg_confidence_score
            FROM addresses
        `;
        
        const queueStatsQuery = `
            SELECT 
                COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_verification,
                COUNT(CASE WHEN status = 'processing' THEN 1 END) as processing_verification,
                COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_verification
            FROM verification_queue
        `;
        
        const [addressStats, queueStats] = await Promise.all([
            pool.query(statsQuery),
            pool.query(queueStatsQuery)
        ]);
        
        const stats = {
            addresses: {
                verified: parseInt(addressStats.rows[0].verified_count),
                pending: parseInt(addressStats.rows[0].pending_count),
                rejected: parseInt(addressStats.rows[0].rejected_count),
                flagged: parseInt(addressStats.rows[0].flagged_count),
                total: parseInt(addressStats.rows[0].total_addresses),
                avg_confidence: parseFloat(addressStats.rows[0].avg_confidence_score) || 0
            },
            verification_queue: {
                pending: parseInt(queueStats.rows[0].pending_verification),
                processing: parseInt(queueStats.rows[0].processing_verification),
                completed: parseInt(queueStats.rows[0].completed_verification)
            }
        };
        
        // Calculate verification rate
        const totalProcessed = stats.addresses.verified + stats.addresses.rejected;
        stats.verification_rate = stats.addresses.total > 0 
            ? ((totalProcessed / stats.addresses.total) * 100).toFixed(1)
            : 0;
        
        res.json(stats);
        
    } catch (error) {
        console.error('Error getting verification stats:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * GET /api/verification/duplicates - Get addresses with duplicate reports
 */
router.get('/duplicates', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const limit = parseInt(req.query.limit) || 50;
        const addresses = await getAddressesNeedingReview(pool, limit);
        
        res.json({
            addresses_needing_review: addresses,
            count: addresses.length
        });
        
    } catch (error) {
        console.error('Error getting duplicate addresses:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

/**
 * POST /api/verification/batch-process - Batch process addresses
 */
router.post('/batch-process', async (req, res) => {
    const pool = req.app.locals.pool;
    
    try {
        const { queue_ids, action, confidence_score } = req.body;
        
        if (!Array.isArray(queue_ids) || queue_ids.length === 0) {
            return res.status(400).json({
                error: 'queue_ids must be a non-empty array'
            });
        }
        
        if (!['approve', 'reject', 'flag'].includes(action)) {
            return res.status(400).json({
                error: 'Invalid action. Must be approve, reject, or flag'
            });
        }
        
        await pool.query('BEGIN');
        
        let verificationStatus;
        let newConfidenceScore;
        
        switch (action) {
            case 'approve':
                verificationStatus = 'verified';
                newConfidenceScore = confidence_score || 95;
                break;
            case 'reject':
                verificationStatus = 'rejected';
                newConfidenceScore = 0;
                break;
            case 'flag':
                verificationStatus = 'flagged';
                newConfidenceScore = confidence_score || 25;
                break;
        }
        
        // Update verification queue items
        await pool.query(
            `UPDATE verification_queue 
             SET status = 'completed', 
                 processed_at = CURRENT_TIMESTAMP,
                 ai_confidence = $2
             WHERE id = ANY($1)`,
            [queue_ids, newConfidenceScore]
        );
        
        // Get address IDs from queue items
        const addressResult = await pool.query(
            'SELECT address_id FROM verification_queue WHERE id = ANY($1)',
            [queue_ids]
        );
        
        const addressIds = addressResult.rows.map(row => row.address_id);
        
        // Update addresses
        await pool.query(
            `UPDATE addresses 
             SET verification_status = $1, 
                 confidence_score = $2,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = ANY($3)`,
            [verificationStatus, newConfidenceScore, addressIds]
        );
        
        await pool.query('COMMIT');
        
        res.json({
            success: true,
            message: `${queue_ids.length} addresses ${action}ed successfully`,
            processed_count: queue_ids.length,
            verification_status: verificationStatus
        });
        
    } catch (error) {
        await pool.query('ROLLBACK');
        console.error('Error batch processing verification:', error);
        res.status(500).json({ 
            error: 'Internal server error' 
        });
    }
});

module.exports = router;