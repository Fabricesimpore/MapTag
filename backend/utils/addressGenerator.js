const { v4: uuidv4 } = require('uuid');

/**
 * Generate a unique address code based on coordinates and location
 * Format: BF-CITY-GRID-XXXX
 */
function generateAddressCode(latitude, longitude, placeName) {
    // Determine city code based on coordinates
    const cityCode = determineCityCode(latitude, longitude);
    
    // Create grid system based on coordinates
    // Scale coordinates to create meaningful grid references
    const latGrid = Math.floor((latitude + 90) * 100);
    const lonGrid = Math.floor((longitude + 180) * 100);
    
    // Take last 4 digits of grid coordinates for compactness
    const gridCode = `${latGrid}${lonGrid}`.slice(-4);
    
    // Generate random suffix for uniqueness
    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    
    // Final code format: BF-CITY-GRID-XXXX
    return `BF-${cityCode}-${gridCode}-${randomSuffix}`;
}

/**
 * Determine city code based on GPS coordinates
 * Uses approximate bounding boxes for major cities in Burkina Faso
 */
function determineCityCode(lat, lon) {
    // Ouagadougou: ~12.3714° N, 1.5197° W
    if (lat > 12.2 && lat < 12.5 && lon > -1.7 && lon < -1.3) {
        return 'OUA';
    }
    
    // Bobo-Dioulasso: ~11.1784° N, 4.2953° W  
    if (lat > 11.0 && lat < 11.3 && lon > -4.5 && lon < -4.0) {
        return 'BOB';
    }
    
    // Koudougou: ~12.2525° N, 2.3617° W
    if (lat > 12.1 && lat < 12.4 && lon > -2.5 && lon < -2.2) {
        return 'KOU';
    }
    
    // Banfora: ~10.6333° N, 4.7667° W
    if (lat > 10.5 && lat < 10.8 && lon > -4.9 && lon < -4.6) {
        return 'BAN';
    }
    
    // Ouahigouya: ~13.5833° N, 2.4167° W
    if (lat > 13.4 && lat < 13.7 && lon > -2.6 && lon < -2.2) {
        return 'OUA';
    }
    
    // Fada N'Gourma: ~12.0614° N, 0.3583° E
    if (lat > 11.9 && lat < 12.2 && lon > 0.2 && lon < 0.5) {
        return 'FAD';
    }
    
    // Default for other locations
    return 'OTH';
}

/**
 * Validate address code format
 */
function validateAddressCode(code) {
    const pattern = /^BF-[A-Z]{3}-\d{4}-[A-Z0-9]{4}$/;
    return pattern.test(code);
}

/**
 * Parse address code to extract components
 */
function parseAddressCode(code) {
    if (!validateAddressCode(code)) {
        throw new Error('Invalid address code format');
    }
    
    const parts = code.split('-');
    return {
        country: parts[0],
        city: parts[1],
        grid: parts[2],
        unique: parts[3]
    };
}

/**
 * Generate a short code for SMS sharing (8 characters)
 */
function generateShortCode() {
    return Math.random().toString(36).substring(2, 10).toUpperCase();
}

module.exports = {
    generateAddressCode,
    determineCityCode,
    validateAddressCode,
    parseAddressCode,
    generateShortCode
};