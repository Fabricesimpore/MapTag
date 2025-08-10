# 🚀 MapTag BF Production Deployment Guide

This guide provides step-by-step instructions for deploying MapTag BF to production.

## 📋 Prerequisites

### System Requirements
- **Server**: 2+ CPU cores, 4GB+ RAM, 50GB+ storage
- **OS**: Ubuntu 20.04+ or CentOS 8+
- **Docker**: 20.10+
- **Docker Compose**: v2+
- **Domain**: Registered domain name (e.g., maptag.bf)

### Required Accounts/Services
- **Domain Registrar**: For DNS management
- **SSL Certificate**: Let's Encrypt (free) or commercial
- **Email Service**: For notifications and alerts
- **Optional**: Cloud storage for backups (AWS S3, etc.)

## 🛠️ Step 1: Server Setup

### 1.1 Initial Server Configuration

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git unzip jq

# Create application user
sudo useradd -m -s /bin/bash maptag
sudo usermod -aG sudo maptag
```

### 1.2 Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Restart to apply group changes
sudo reboot
```

## 📦 Step 2: Application Deployment

### 2.1 Clone Repository

```bash
# Switch to application user
sudo su - maptag

# Clone repository
git clone <your-repository-url> /home/maptag/maptag-bf
cd /home/maptag/maptag-bf
```

### 2.2 Configure Environment

```bash
# Copy and edit production environment file
cp backend/.env.example backend/.env.production

# Edit with your production values
nano backend/.env.production
```

**Required Environment Variables:**

```bash
# Application
NODE_ENV=production
PORT=3000

# Database (use strong credentials)
DATABASE_URL=postgresql://maptag_user:STRONG_PASSWORD_HERE@localhost:5432/maptag_bf_prod

# Security (generate strong secrets)
JWT_SECRET=GENERATE_32_CHAR_RANDOM_STRING_HERE
SESSION_SECRET=ANOTHER_32_CHAR_RANDOM_STRING_HERE

# Domain
CORS_ORIGIN=https://maptag.bf,https://www.maptag.bf

# Monitoring
NOTIFICATION_EMAIL=admin@maptag.bf
```

### 2.3 Deploy Services

```bash
# Run deployment script
./scripts/deploy.sh production

# Or manual deployment
docker-compose -f docker-compose.yml up -d
```

### 2.4 Verify Deployment

```bash
# Check service status
docker-compose ps

# Test API endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/verification/stats

# Run monitoring check
./scripts/monitoring.sh monitor
```

## 🌐 Step 3: Domain and SSL Configuration

### 3.1 DNS Configuration

Configure your domain DNS records:

```
A    @           YOUR_SERVER_IP
A    www         YOUR_SERVER_IP
CNAME api       @
```

### 3.2 Install Nginx

```bash
# Install Nginx
sudo apt install nginx

# Copy configuration
sudo cp nginx/default.conf /etc/nginx/sites-available/maptag.bf
sudo ln -s /etc/nginx/sites-available/maptag.bf /etc/nginx/sites-enabled/

# Remove default config
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t
sudo systemctl reload nginx
```

### 3.3 SSL Certificate with Let's Encrypt

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d maptag.bf -d www.maptag.bf

# Test automatic renewal
sudo certbot renew --dry-run
```

### 3.4 Update Nginx Configuration

Edit `/etc/nginx/sites-available/maptag.bf` to update server names:

```nginx
server_name maptag.bf www.maptag.bf;
```

Reload Nginx:

```bash
sudo systemctl reload nginx
```

## 🔒 Step 4: Security Hardening

### 4.1 Firewall Configuration

```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH, HTTP, HTTPS
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check status
sudo ufw status
```

### 4.2 Database Security

```bash
# Create dedicated database user
docker exec -it maptag-postgres psql -U postgres -c "
CREATE USER maptag_user WITH PASSWORD 'STRONG_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON DATABASE maptag_bf TO maptag_user;
"

# Update environment file with new credentials
nano backend/.env.production
```

### 4.3 Regular Updates

```bash
# Create update script
cat > /home/maptag/update.sh << 'EOF'
#!/bin/bash
cd /home/maptag/maptag-bf
git pull origin main
docker-compose build
docker-compose up -d
EOF

chmod +x /home/maptag/update.sh
```

## 📊 Step 5: Monitoring and Backups

### 5.1 Set up System Monitoring

```bash
# Install monitoring script as systemd service
sudo cp scripts/monitoring.sh /usr/local/bin/maptag-monitor
sudo chmod +x /usr/local/bin/maptag-monitor

# Create systemd service
sudo tee /etc/systemd/system/maptag-monitor.service > /dev/null <<EOF
[Unit]
Description=MapTag BF Monitoring Service
After=network.target

[Service]
Type=simple
User=maptag
WorkingDirectory=/home/maptag/maptag-bf
ExecStart=/usr/local/bin/maptag-monitor continuous
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable maptag-monitor
sudo systemctl start maptag-monitor
```

### 5.2 Configure Automatic Backups

```bash
# Create backup script
cat > /home/maptag/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/maptag/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Database backup
docker exec maptag-postgres pg_dump -U maptag maptag_bf > $BACKUP_DIR/db_backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/db_backup_$DATE.sql

# Keep only last 7 days of backups
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: db_backup_$DATE.sql.gz"
EOF

chmod +x /home/maptag/backup.sh

# Add to crontab
crontab -e
# Add this line:
# 0 2 * * * /home/maptag/backup.sh
```

### 5.3 Log Rotation

```bash
# Configure log rotation
sudo tee /etc/logrotate.d/maptag > /dev/null <<EOF
/home/maptag/maptag-bf/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    su maptag maptag
}
EOF
```

## 📱 Step 6: Mobile App Distribution

### 6.1 Build Release APK

```bash
# In the Flutter app directory
cd frontend/maptag_bf

# Update API URL in lib/services/api_service.dart
# Change baseUrl to: https://maptag.bf/api

# Build release APK
flutter build apk --release

# APK will be in: build/app/outputs/flutter-apk/app-release.apk
```

### 6.2 Distribution Options

**Option A: Direct Download**
- Upload APK to your website
- Create download page with installation instructions

**Option B: Google Play Store**
- Follow Google Play Console guidelines
- Upload signed APK/AAB
- Complete store listing

**Option C: Alternative App Stores**
- F-Droid for open source distribution
- APKPure, Aptoide, etc.

## 🔍 Step 7: Testing and Validation

### 7.1 Production Testing Checklist

```bash
# API Testing
curl https://maptag.bf/health
curl https://maptag.bf/api/addresses
curl -X POST https://maptag.bf/api/addresses \
  -H "Content-Type: application/json" \
  -d '{"latitude": 12.3714, "longitude": -1.5197, "placeName": "Test Location", "category": "Test"}'

# SSL Testing
curl -I https://maptag.bf

# Mobile App Testing
# - Install APK on Android device
# - Test address creation
# - Test offline functionality
# - Test photo upload
```

### 7.2 Performance Testing

```bash
# Install Apache Bench
sudo apt install apache2-utils

# Test API performance
ab -n 100 -c 10 https://maptag.bf/api/addresses
```

## 🚨 Step 8: Launch Preparation

### 8.1 Pre-Launch Checklist

- [ ] All services running and healthy
- [ ] SSL certificate installed and working
- [ ] Database backups configured
- [ ] Monitoring system active
- [ ] Mobile app tested on multiple devices
- [ ] API performance acceptable
- [ ] Security review completed
- [ ] User documentation prepared

### 8.2 Launch Day Tasks

1. **Final System Check**
   ```bash
   ./scripts/monitoring.sh monitor
   ```

2. **Database Optimization**
   ```bash
   docker exec maptag-postgres psql -U maptag maptag_bf -c "VACUUM ANALYZE;"
   ```

3. **Clear Logs**
   ```bash
   > /home/maptag/maptag-bf/logs/monitoring.log
   ```

4. **Announce Launch**
   - Social media
   - Press release
   - Community outreach

## 📚 Step 9: Operations and Maintenance

### 9.1 Daily Operations

```bash
# Check system status
./scripts/monitoring.sh monitor

# Check logs
tail -f logs/monitoring.log
docker-compose logs --tail=100

# Backup verification
ls -la backups/
```

### 9.2 Weekly Maintenance

```bash
# System updates
sudo apt update && sudo apt upgrade -y

# Docker cleanup
docker system prune -f

# Database maintenance
docker exec maptag-postgres psql -U maptag maptag_bf -c "VACUUM ANALYZE;"
```

### 9.3 Troubleshooting Common Issues

**Service Won't Start:**
```bash
# Check logs
docker-compose logs backend

# Restart services
docker-compose restart backend
```

**Database Connection Issues:**
```bash
# Check database status
docker-compose ps postgres
docker exec maptag-postgres pg_isready -U maptag
```

**High Memory Usage:**
```bash
# Check resource usage
docker stats
free -h
df -h
```

## 🎯 Success Metrics

Monitor these key metrics:

- **Uptime**: Target 99.9%
- **Response Time**: API < 500ms
- **Address Creation Rate**: Track daily/weekly
- **User Growth**: Monitor app downloads
- **Verification Rate**: Target >85%

## 🆘 Emergency Procedures

### Service Outage

1. Check monitoring alerts
2. Restart services: `docker-compose restart`
3. Check resource usage
4. Scale services if needed
5. Contact technical support

### Data Recovery

1. Stop services: `docker-compose down`
2. Restore from backup: `gunzip -c backup.sql.gz | docker exec -i maptag-postgres psql -U maptag maptag_bf`
3. Start services: `docker-compose up -d`
4. Verify data integrity

## 📞 Support Contacts

- **Technical Support**: tech@maptag.bf
- **Emergency**: +226 XX XX XX XX
- **Status Page**: https://status.maptag.bf

---

**🎉 Congratulations!** MapTag BF is now ready for production use in Burkina Faso! 🇧🇫

For additional support, refer to the main README.md and DEPLOYMENT.md files.