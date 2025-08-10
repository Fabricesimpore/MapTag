# MapTag BF Deployment Guide

This guide covers deployment options for MapTag BF, from development to production environments.

## 🏗️ Deployment Options

### 1. Local Development

**Quick Start:**
```bash
# Clone repository
git clone <repository-url>
cd maptag-bf

# Start with Docker
docker-compose up -d

# Or manual setup
cd backend && npm install && npm run dev
```

### 2. Docker Production Deployment

**Prerequisites:**
- Docker 20.10+
- Docker Compose v2
- 2GB+ RAM
- 20GB+ storage

**Steps:**
```bash
# 1. Prepare environment
cp .env.example .env
# Edit .env with production values

# 2. Start services
docker-compose -f docker-compose.yml up -d

# 3. Verify deployment
curl http://localhost:3000/health
```

### 3. Cloud Deployment (Railway/Heroku/DigitalOcean)

#### Railway Deployment

1. **Connect Repository**
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli
   
   # Login and deploy
   railway login
   railway link
   railway up
   ```

2. **Configure Environment Variables**
   - `DATABASE_URL`: Railway PostgreSQL URL
   - `NODE_ENV`: production
   - `JWT_SECRET`: Strong random string
   - `PORT`: 3000

#### Heroku Deployment

1. **Prepare Heroku App**
   ```bash
   # Install Heroku CLI and login
   heroku create maptag-bf
   heroku addons:create heroku-postgresql:hobby-dev
   heroku config:set NODE_ENV=production
   ```

2. **Deploy**
   ```bash
   git push heroku main
   ```

#### DigitalOcean App Platform

1. **Create App Spec** (`app.yaml`):
   ```yaml
   name: maptag-bf
   services:
   - name: backend
     source_dir: /backend
     github:
       repo: your-repo/maptag-bf
       branch: main
     run_command: npm start
     environment_slug: node-js
     instance_count: 1
     instance_size_slug: basic-xxs
     envs:
     - key: NODE_ENV
       value: production
   databases:
   - name: db
     engine: PG
     version: "13"
     size: basic
   ```

### 4. VPS/Dedicated Server Deployment

#### Ubuntu 20.04/22.04 Setup

1. **System Preparation**
   ```bash
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Application Setup**
   ```bash
   # Create app user
   sudo useradd -m -s /bin/bash maptag
   sudo usermod -aG docker maptag
   
   # Switch to app user
   sudo su - maptag
   
   # Clone and setup
   git clone <repository-url> /home/maptag/maptag-bf
   cd /home/maptag/maptag-bf
   cp .env.example .env
   # Edit .env file
   ```

3. **Start Services**
   ```bash
   docker-compose up -d
   ```

4. **Set up Nginx (Optional reverse proxy)**
   ```bash
   sudo apt install nginx
   sudo cp deployment/nginx.conf /etc/nginx/sites-available/maptag-bf
   sudo ln -s /etc/nginx/sites-available/maptag-bf /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

## 🔒 SSL/HTTPS Setup

### Using Let's Encrypt

1. **Install Certbot**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   ```

2. **Get Certificate**
   ```bash
   sudo certbot --nginx -d maptag.bf -d www.maptag.bf
   ```

3. **Auto-renewal Setup**
   ```bash
   sudo crontab -e
   # Add: 0 12 * * * /usr/bin/certbot renew --quiet
   ```

### Using CloudFlare (Recommended)

1. **Add Domain to CloudFlare**
2. **Enable SSL/TLS (Full mode)**
3. **Configure DNS records:**
   - A record: maptag.bf → server IP
   - CNAME: www.maptag.bf → maptag.bf

## 📊 Production Configuration

### Environment Variables

```bash
# Required Production Variables
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@host:5432/maptag_bf
JWT_SECRET=very-secure-random-string-min-32-chars
MAX_FILE_SIZE=5242880
CORS_ORIGIN=https://maptag.bf

# Optional but Recommended
REDIS_URL=redis://localhost:6379
LOG_LEVEL=info
BACKUP_RETENTION_DAYS=30
RATE_LIMIT_MAX_REQUESTS=100
TRUST_PROXY=true
```

### Database Configuration

**PostgreSQL Optimization:**
```sql
-- postgresql.conf adjustments
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
```

### Docker Production Overrides

Create `docker-compose.prod.yml`:
```yaml
version: '3.8'
services:
  postgres:
    restart: always
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data

  backend:
    restart: always
    environment:
      NODE_ENV: production
      DATABASE_URL: ${DATABASE_URL}
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

volumes:
  postgres_prod_data:
    driver: local
```

## 🔧 Monitoring & Logging

### Application Monitoring

1. **Health Check Endpoint**
   ```bash
   curl https://maptag.bf/health
   ```

2. **Database Monitoring**
   ```sql
   -- Check connection count
   SELECT count(*) FROM pg_stat_activity;
   
   -- Check slow queries
   SELECT query, mean_time 
   FROM pg_stat_statements 
   ORDER BY mean_time DESC LIMIT 5;
   ```

3. **Log Monitoring**
   ```bash
   # Application logs
   docker-compose logs -f backend
   
   # Database logs
   docker-compose logs -f postgres
   
   # Nginx logs
   tail -f /var/log/nginx/access.log
   ```

### Setting up Monitoring Stack (Optional)

```yaml
# Add to docker-compose.yml
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin123
```

## 🔄 Backup & Recovery

### Automated Database Backups

1. **Backup Script** (`scripts/backup.sh`):
   ```bash
   #!/bin/bash
   DATE=$(date +%Y%m%d_%H%M%S)
   BACKUP_DIR="/home/maptag/backups"
   
   mkdir -p $BACKUP_DIR
   
   docker exec maptag-postgres pg_dump -U maptag maptag_bf > $BACKUP_DIR/maptag_backup_$DATE.sql
   
   # Keep only last 7 days
   find $BACKUP_DIR -name "maptag_backup_*.sql" -mtime +7 -delete
   ```

2. **Cron Job Setup**:
   ```bash
   crontab -e
   # Add: 0 2 * * * /home/maptag/scripts/backup.sh
   ```

### File Backup

```bash
# Backup uploaded files
rsync -av /home/maptag/maptag-bf/backend/uploads/ backup-server:/backups/maptag-uploads/
```

### Recovery Procedure

```bash
# Restore database
docker exec -i maptag-postgres psql -U maptag maptag_bf < backup_file.sql

# Restore files
rsync -av backup-server:/backups/maptag-uploads/ /home/maptag/maptag-bf/backend/uploads/
```

## 🚀 Performance Optimization

### Database Optimization

```sql
-- Create additional indexes for performance
CREATE INDEX CONCURRENTLY idx_addresses_created_at_desc ON addresses (created_at DESC);
CREATE INDEX CONCURRENTLY idx_addresses_verification_category ON addresses (verification_status, category);

-- Update table statistics
ANALYZE addresses;
```

### Application Optimization

1. **Enable Redis Caching**
   ```bash
   # Add to docker-compose.yml
   REDIS_URL=redis://redis:6379
   ```

2. **Configure Node.js Clustering**
   ```javascript
   // Add to server.js
   const cluster = require('cluster');
   const numCPUs = require('os').cpus().length;
   
   if (cluster.isMaster && process.env.NODE_ENV === 'production') {
     for (let i = 0; i < numCPUs; i++) {
       cluster.fork();
     }
   } else {
     // Your app code
   }
   ```

### CDN Setup (CloudFlare)

1. **Configure Caching Rules:**
   - Cache static assets: 1 year
   - Cache API responses: 5 minutes
   - Cache uploaded images: 1 week

2. **Page Rules:**
   - `maptag.bf/uploads/*` → Cache Level: Cache Everything

## 📱 Mobile App Deployment

### Android APK Build

```bash
cd frontend/maptag_bf
flutter build apk --release
```

### iOS App Store

```bash
cd frontend/maptag_bf
flutter build ios --release
```

### App Distribution

1. **Google Play Store:** Follow Flutter deployment guide
2. **Direct APK:** Host on website with download instructions
3. **Firebase Distribution:** For beta testing

## 🔍 Troubleshooting

### Common Issues

1. **Database Connection Errors**
   ```bash
   # Check if PostgreSQL is running
   docker-compose ps postgres
   
   # Check logs
   docker-compose logs postgres
   ```

2. **File Upload Issues**
   ```bash
   # Check upload directory permissions
   ls -la backend/uploads/
   
   # Fix permissions if needed
   sudo chown -R maptag:maptag backend/uploads/
   chmod 755 backend/uploads/
   ```

3. **High Memory Usage**
   ```bash
   # Monitor resources
   docker stats
   
   # Restart services if needed
   docker-compose restart backend
   ```

### Performance Issues

```bash
# Check slow queries
docker exec -it maptag-postgres psql -U maptag -c "
  SELECT query, mean_time, calls 
  FROM pg_stat_statements 
  ORDER BY mean_time DESC LIMIT 10;
"

# Monitor API response times
curl -w "@curl-format.txt" -o /dev/null -s "http://localhost:3000/health"
```

## 🔄 Updates & Maintenance

### Application Updates

```bash
# 1. Pull latest changes
git pull origin main

# 2. Update dependencies
docker-compose pull

# 3. Restart services
docker-compose down && docker-compose up -d

# 4. Run migrations (if any)
docker-compose exec backend npm run migrate
```

### Security Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d

# Update Node.js dependencies
cd backend && npm audit fix
```

This deployment guide covers the essential steps for getting MapTag BF running in production. For specific questions or issues, please refer to the main README or create an issue.