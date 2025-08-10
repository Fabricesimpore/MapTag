-- MapTag BF Database Schema
-- Create database first: createdb maptag_bf

-- Enable PostGIS extension for geospatial operations
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create addresses table
CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) UNIQUE NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    place_name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    building_photo_url VARCHAR(500),
    confidence_score INTEGER DEFAULT 0,
    verification_status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    geom GEOMETRY(POINT, 4326) -- PostGIS geometry column
);

-- Create duplicate reports table
CREATE TABLE duplicate_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_id UUID REFERENCES addresses(id),
    reported_duplicate_id UUID REFERENCES addresses(id),
    distance_meters DECIMAL(8, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create businesses table (for Phase 2)
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_id UUID REFERENCES addresses(id) UNIQUE,
    business_name VARCHAR(255) NOT NULL,
    opening_hours JSONB,
    phone_number VARCHAR(20),
    mobile_money_number VARCHAR(20),
    logo_url VARCHAR(500),
    pro_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create verification queue table
CREATE TABLE verification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_id UUID REFERENCES addresses(id),
    verification_type VARCHAR(50) NOT NULL, -- 'photo_match', 'duplicate_check', 'manual'
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    ai_confidence DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_addresses_location ON addresses USING GIST (geom);
CREATE INDEX idx_addresses_code ON addresses(code);
CREATE INDEX idx_addresses_verification_status ON addresses(verification_status);
CREATE INDEX idx_addresses_created_at ON addresses(created_at);
CREATE INDEX idx_duplicate_reports_address_id ON duplicate_reports(address_id);
CREATE INDEX idx_businesses_address_id ON businesses(address_id);
CREATE INDEX idx_verification_queue_status ON verification_queue(status);

-- Function to automatically update geom column when lat/lon changes
CREATE OR REPLACE FUNCTION update_geom_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update geom on insert/update
CREATE TRIGGER trigger_update_geom
    BEFORE INSERT OR UPDATE ON addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_geom_column();

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on address changes
CREATE TRIGGER trigger_update_addresses_updated_at
    BEFORE UPDATE ON addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();