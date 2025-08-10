#!/bin/bash

# MapTag BF Database Setup Script
set -e

echo "🗄️  Setting up MapTag BF Database..."

# Configuration
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-maptag}
DB_PASSWORD=${DB_PASSWORD:-password123}
DB_NAME=${DB_NAME:-maptag_bf}

echo "Database Configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"  
echo "  User: $DB_USER"
echo "  Database: $DB_NAME"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
  echo "  Waiting for database connection..."
  sleep 2
done

echo "✅ PostgreSQL is ready"

# Create database if it doesn't exist
echo "📊 Creating database '$DB_NAME' if it doesn't exist..."
PGPASSWORD=$DB_PASSWORD createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME 2>/dev/null || echo "  Database already exists"

# Run schema setup
echo "🏗️  Setting up database schema..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f ../backend/database.sql

# Verify installation
echo "🔍 Verifying database setup..."
TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | tr -d ' ')

if [ "$TABLE_COUNT" -ge "4" ]; then
    echo "✅ Database setup completed successfully! ($TABLE_COUNT tables created)"
else
    echo "❌ Database setup may have failed. Only $TABLE_COUNT tables found."
    exit 1
fi

# Create sample data for testing (optional)
if [ "$1" = "--with-sample-data" ]; then
    echo "🌱 Adding sample data..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOF'
-- Sample addresses for testing
INSERT INTO addresses (code, latitude, longitude, place_name, category, verification_status, confidence_score) VALUES
('BF-OUA-1234-TEST', 12.3714, -1.5197, 'Maison Test Ouagadougou', 'Résidence', 'verified', 95),
('BF-BOB-5678-DEMO', 11.1784, -4.2953, 'Commerce Test Bobo', 'Commerce', 'verified', 90),
('BF-OUA-9999-SAMP', 12.3800, -1.5100, 'École Test', 'École', 'pending', 0);

INSERT INTO verification_queue (address_id, verification_type, status) 
SELECT id, 'photo_match', 'pending' FROM addresses WHERE verification_status = 'pending';

EOF
    echo "✅ Sample data added"
fi

echo ""
echo "🎉 MapTag BF Database is ready!"
echo ""
echo "Connection details:"
echo "  postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
echo ""
echo "Next steps:"
echo "  1. Update your .env file with the database URL"
echo "  2. Start the backend server: npm start"
echo "  3. Test the API endpoints"