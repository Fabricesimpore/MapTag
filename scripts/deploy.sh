#!/bin/bash

# MapTag BF Production Deployment Script
set -e

echo "🚀 MapTag BF Production Deployment"
echo "=================================="

# Configuration
ENVIRONMENT=${1:-production}
DOMAIN=${DOMAIN:-maptag.bf}
DB_BACKUP=${DB_BACKUP:-true}

echo "Environment: $ENVIRONMENT"
echo "Domain: $DOMAIN"
echo "Database backup: $DB_BACKUP"
echo ""

# Pre-deployment checks
echo "📋 Pre-deployment checks..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if required files exist
REQUIRED_FILES=("docker-compose.yml" "backend/Dockerfile" "backend/package.json")
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Required file missing: $file"
        exit 1
    fi
done

echo "✅ Pre-deployment checks passed"
echo ""

# Backup database if enabled
if [[ "$DB_BACKUP" == "true" ]]; then
    echo "💾 Creating database backup..."
    BACKUP_DIR="./backups"
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/maptag_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    if docker-compose ps postgres | grep -q "Up"; then
        docker exec maptag-postgres pg_dump -U maptag maptag_bf > "$BACKUP_FILE"
        echo "✅ Database backup created: $BACKUP_FILE"
    else
        echo "⚠️  Database not running, skipping backup"
    fi
    echo ""
fi

# Pull latest changes (if in git repository)
if [[ -d ".git" ]]; then
    echo "📥 Pulling latest changes..."
    git pull origin main || echo "⚠️  Git pull failed or not in git repository"
    echo ""
fi

# Build and deploy
echo "🏗️  Building and deploying services..."

# Build images
echo "Building Docker images..."
docker-compose build

# Start services
echo "Starting services..."
if [[ "$ENVIRONMENT" == "production" ]]; then
    docker-compose -f docker-compose.yml up -d
else
    docker-compose up -d
fi

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    HEALTHY_COUNT=$(docker-compose ps --filter health=healthy | wc -l)
    if [[ $HEALTHY_COUNT -ge 3 ]]; then # postgres, redis, backend
        echo "✅ All services are healthy"
        break
    fi
    
    echo "  Attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS - Waiting for services..."
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
done

if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
    echo "❌ Services failed to become healthy within $(($MAX_ATTEMPTS * 10)) seconds"
    echo "Service status:"
    docker-compose ps
    exit 1
fi

# Run post-deployment tests
echo ""
echo "🧪 Running post-deployment tests..."

# Test health endpoint
HEALTH_STATUS=$(curl -s http://localhost:3000/health | jq -r '.status' 2>/dev/null || echo "ERROR")
if [[ "$HEALTH_STATUS" == "OK" ]]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Test database connection
DB_TEST=$(curl -s http://localhost:3000/api/verification/stats | jq -r '.success' 2>/dev/null || echo "false")
if [[ "$DB_TEST" == "true" ]]; then
    echo "✅ Database connection test passed"
else
    echo "❌ Database connection test failed"
    exit 1
fi

# Test address creation
CREATE_TEST=$(curl -s -X POST http://localhost:3000/api/addresses \
    -H "Content-Type: application/json" \
    -d '{"latitude": 12.3714, "longitude": -1.5197, "placeName": "Deployment Test", "category": "Test"}' | \
    jq -r '.success' 2>/dev/null || echo "false")
if [[ "$CREATE_TEST" == "true" ]]; then
    echo "✅ Address creation test passed"
else
    echo "❌ Address creation test failed"
    exit 1
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Service URLs:"
echo "  🌐 API Server: http://localhost:3000"
echo "  💚 Health Check: http://localhost:3000/health"
echo "  🏠 Addresses API: http://localhost:3000/api/addresses"
echo "  📊 Statistics: http://localhost:3000/api/verification/stats"
echo ""

if [[ "$ENVIRONMENT" == "production" ]]; then
    echo "Production URLs (once domain is configured):"
    echo "  🌐 Public API: https://$DOMAIN/api"
    echo "  💚 Health Check: https://$DOMAIN/health"
    echo ""
fi

echo "Next steps:"
echo "1. Configure domain name and SSL certificates"
echo "2. Set up monitoring and alerting"
echo "3. Configure automatic backups"
echo "4. Deploy mobile app to app stores"
echo ""

# Show service status
echo "Current service status:"
docker-compose ps