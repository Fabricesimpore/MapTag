const geolib = require('geolib');

/**
 * Check for duplicate addresses within a specified radius
 * Uses PostgreSQL with PostGIS for efficient geospatial queries
 */
async function checkForDuplicates(pool, latitude, longitude, radius = 30, excludeId = null) {
    try {
        let query = `
            SELECT 
                id, 
                code, 
                place_name, 
                latitude, 
                longitude,
                category,
                verification_status,
                ST_Distance(
                    geom, 
                    ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
                ) as distance_meters
            FROM addresses 
            WHERE ST_DWithin(
                geom, 
                ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 
                $3
            )
        `;
        
        let queryParams = [longitude, latitude, radius];
        
        // Exclude specific address ID if provided (useful for updates)
        if (excludeId) {
            query += ' AND id != $4';
            queryParams.push(excludeId);
        }
        
        query += ' ORDER BY distance_meters;';
        
        const result = await pool.query(query, queryParams);
        return result.rows.map(row => ({
            ...row,
            distance_meters: parseFloat(row.distance_meters)
        }));
    } catch (error) {
        console.error('Error checking for duplicates:', error);
        throw error;
    }
}

/**
 * Advanced duplicate detection with similarity scoring
 * Combines distance, name similarity, and category matching
 */
async function checkForDuplicatesAdvanced(pool, latitude, longitude, placeName, category, radius = 50) {
    try {
        const nearbyAddresses = await checkForDuplicates(pool, latitude, longitude, radius);
        
        const duplicatesWithScore = nearbyAddresses.map(address => {
            const distanceScore = calculateDistanceScore(address.distance_meters);
            const nameScore = calculateNameSimilarity(placeName, address.place_name);
            const categoryScore = category === address.category ? 1 : 0;
            
            // Weighted composite score
            const compositeScore = (
                distanceScore * 0.5 +
                nameScore * 0.3 +
                categoryScore * 0.2
            );
            
            return {
                ...address,
                duplicate_probability: compositeScore,
                is_likely_duplicate: compositeScore > 0.7
            };
        });
        
        // Sort by duplicate probability (highest first)
        return duplicatesWithScore.sort((a, b) => b.duplicate_probability - a.duplicate_probability);
    } catch (error) {
        console.error('Error in advanced duplicate detection:', error);
        throw error;
    }
}

/**
 * Calculate distance-based duplicate score
 * Returns 1.0 for very close addresses (0-10m), decreasing to 0 at max radius
 */
function calculateDistanceScore(distance) {
    if (distance <= 10) return 1.0;
    if (distance <= 20) return 0.8;
    if (distance <= 30) return 0.6;
    if (distance <= 50) return 0.4;
    return 0.2;
}

/**
 * Calculate name similarity using Levenshtein distance
 */
function calculateNameSimilarity(name1, name2) {
    if (!name1 || !name2) return 0;
    
    const str1 = name1.toLowerCase().trim();
    const str2 = name2.toLowerCase().trim();
    
    if (str1 === str2) return 1;
    
    const distance = levenshteinDistance(str1, str2);
    const maxLength = Math.max(str1.length, str2.length);
    
    if (maxLength === 0) return 1;
    
    return 1 - (distance / maxLength);
}

/**
 * Levenshtein distance algorithm
 */
function levenshteinDistance(str1, str2) {
    const matrix = Array(str2.length + 1).fill(null).map(() => Array(str1.length + 1).fill(null));
    
    for (let i = 0; i <= str1.length; i++) {
        matrix[0][i] = i;
    }
    
    for (let j = 0; j <= str2.length; j++) {
        matrix[j][0] = j;
    }
    
    for (let j = 1; j <= str2.length; j++) {
        for (let i = 1; i <= str1.length; i++) {
            const cost = str1[i - 1] === str2[j - 1] ? 0 : 1;
            
            matrix[j][i] = Math.min(
                matrix[j][i - 1] + 1,     // insertion
                matrix[j - 1][i] + 1,     // deletion
                matrix[j - 1][i - 1] + cost // substitution
            );
        }
    }
    
    return matrix[str2.length][str1.length];
}

/**
 * Report a duplicate address
 */
async function reportDuplicate(pool, addressId, duplicateId, distance) {
    try {
        const query = `
            INSERT INTO duplicate_reports (address_id, reported_duplicate_id, distance_meters)
            VALUES ($1, $2, $3)
            RETURNING *
        `;
        
        const result = await pool.query(query, [addressId, duplicateId, distance]);
        return result.rows[0];
    } catch (error) {
        console.error('Error reporting duplicate:', error);
        throw error;
    }
}

/**
 * Get addresses with high duplicate probability for manual review
 */
async function getAddressesNeedingReview(pool, limit = 50) {
    try {
        const query = `
            SELECT DISTINCT
                a1.id,
                a1.code,
                a1.place_name,
                a1.latitude,
                a1.longitude,
                a1.category,
                COUNT(dr.id) as duplicate_reports_count
            FROM addresses a1
            LEFT JOIN duplicate_reports dr ON a1.id = dr.address_id
            WHERE a1.verification_status = 'pending'
            GROUP BY a1.id, a1.code, a1.place_name, a1.latitude, a1.longitude, a1.category
            HAVING COUNT(dr.id) > 0
            ORDER BY duplicate_reports_count DESC, a1.created_at DESC
            LIMIT $1
        `;
        
        const result = await pool.query(query, [limit]);
        return result.rows;
    } catch (error) {
        console.error('Error getting addresses needing review:', error);
        throw error;
    }
}

module.exports = {
    checkForDuplicates,
    checkForDuplicatesAdvanced,
    calculateDistanceScore,
    calculateNameSimilarity,
    reportDuplicate,
    getAddressesNeedingReview
};