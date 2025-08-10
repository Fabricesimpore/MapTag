# 🎯 MapTag BF - 7-Day Launch Plan

## **Current Status**: ✅ Backend Complete, Database Running, Docker Ready

All core systems are built and tested. Time to go live!

---

## 📅 **DAY 1-2: Mobile App Build & Test**

### **Step 1: Install Flutter** (if not already installed)
```bash
# On your development machine
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor
```

### **Step 2: Build Mobile App**
```bash
cd maptag-bf/frontend/maptag_bf

# Install dependencies
flutter pub get

# Test build
flutter build apk --debug

# Production build
flutter build apk --release
```

### **Step 3: Test Mobile App**
- Install `app-release.apk` on Android device
- Test GPS location capture in Burkina Faso coordinates
- Create test address: `12.3714, -1.5197` (Ouagadougou)
- Verify offline functionality
- Test address search and list

**✅ Deliverable**: Working APK file ready for distribution

---

## 📅 **DAY 3-4: Production Server Setup**

### **Step 1: Get Server & Domain**
**Server Options:**
- **DigitalOcean Droplet**: $20/month, 4GB RAM
- **Linode VPS**: $24/month, 4GB RAM  
- **AWS EC2 t3.medium**: ~$30/month
- **Local hosting in Burkina Faso**: Contact local providers

**Domain Options:**
- **maptag.bf**: Contact .bf domain registrar
- **maptag.com**: Temporary alternative ($12/year)

### **Step 2: Server Initial Setup**
```bash
# Connect to your server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create app user
useradd -m -s /bin/bash maptag
usermod -aG docker maptag
```

### **Step 3: Deploy MapTag BF**
```bash
# Switch to app user
su - maptag

# Clone repository
git clone <YOUR_REPOSITORY_URL> maptag-bf
cd maptag-bf

# Configure production environment
cp backend/.env.example backend/.env
nano backend/.env  # Edit with strong passwords

# Deploy
./scripts/deploy.sh production
```

**✅ Deliverable**: MapTag BF running on production server

---

## 📅 **DAY 5: Domain & SSL Setup**

### **Step 1: Configure DNS**
Point your domain to your server:
```
A    @       YOUR_SERVER_IP
A    www     YOUR_SERVER_IP
CNAME api   @
```

### **Step 2: Install Nginx & SSL**
```bash
# Install Nginx
apt install nginx

# Copy configuration
cp nginx/default.conf /etc/nginx/sites-available/maptag
ln -s /etc/nginx/sites-available/maptag /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Install SSL certificate
apt install certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### **Step 3: Update Mobile App**
```bash
# Update API base URL in Flutter app
# Edit: frontend/maptag_bf/lib/services/api_service.dart
# Change: static const String _baseUrl = 'https://yourdomain.com/api';

# Rebuild APK
flutter build apk --release
```

**✅ Deliverable**: HTTPS-enabled production API at https://yourdomain.com

---

## 📅 **DAY 6-7: Testing & Launch Prep**

### **Step 1: End-to-End Testing**
```bash
# API Testing
curl https://yourdomain.com/health
curl https://yourdomain.com/api/addresses
curl -X POST https://yourdomain.com/api/addresses \
  -H "Content-Type: application/json" \
  -d '{"latitude": 12.3714, "longitude": -1.5197, "placeName": "Test Ouagadougou", "category": "Résidence"}'

# Mobile App Testing
# - Install updated APK
# - Create real addresses in Ouagadougou
# - Test photo upload
# - Verify sync with server
```

### **Step 2: Set Up Monitoring**
```bash
# Start monitoring service
./scripts/monitoring.sh continuous &

# Set up automatic backups
crontab -e
# Add: 0 2 * * * /home/maptag/maptag-bf/scripts/backup.sh
```

### **Step 3: Create User Materials**
- Installation guide in French
- User manual with screenshots
- Video tutorial (optional)
- Launch announcement

**✅ Deliverable**: Production-ready system with monitoring

---

## 🚀 **LAUNCH DAY (Day 8)**

### **Morning Launch Checklist**
```bash
# System health check
./scripts/monitoring.sh monitor

# Performance test
curl -w "@curl-format.txt" -o /dev/null -s https://yourdomain.com/api/addresses

# Database optimization
docker exec maptag-postgres psql -U maptag maptag_bf -c "VACUUM ANALYZE;"

# Clear logs for fresh start
> logs/monitoring.log
```

### **Launch Activities**
1. **Announce on social media** with screenshots
2. **Share APK download link** 
3. **Contact local tech communities**
4. **Reach out to moto-taxi unions**
5. **Engage with delivery services**

### **Target First Week**
- **50+ addresses created**
- **10+ active users**
- **95%+ uptime**
- **Feedback collection**

---

## 📋 **Required Resources**

### **Immediate Costs**
- **Server**: $20-30/month
- **Domain**: $12-50/year (.com vs .bf)
- **SSL**: Free with Let's Encrypt
- **Total first month**: ~$50

### **Technical Requirements**
- **Server**: 4GB RAM, 50GB storage, Ubuntu 20.04+
- **Domain**: Registered and DNS-configured
- **Development setup**: Flutter SDK installed
- **Android device**: For testing APK

### **Optional Enhancements**
- **CDN**: CloudFlare (free tier)
- **Email service**: For notifications
- **Analytics**: Google Analytics
- **App distribution**: Google Play Developer ($25 one-time)

---

## 🎯 **Success Metrics Week 1**

### **Technical Metrics**
- ✅ **Uptime**: >95%
- ✅ **API Response Time**: <500ms
- ✅ **Address Creation Success**: >90%
- ✅ **Mobile App Stability**: No crashes

### **User Metrics**
- 🎯 **Addresses Created**: 50+
- 🎯 **Active Users**: 10+
- 🎯 **App Downloads**: 25+
- 🎯 **User Retention**: 70%+

### **Geographic Coverage**
- 🎯 **Ouagadougou**: Primary focus
- 🎯 **Bobo-Dioulasso**: Secondary
- 🎯 **Other cities**: Opportunistic

---

## 🆘 **If You Need Help**

### **Technical Issues**
```bash
# Check logs
docker-compose logs backend
tail -f logs/monitoring.log

# Restart services
docker-compose restart

# Database issues
docker exec -it maptag-postgres psql -U maptag maptag_bf
```

### **Common Problems & Solutions**

**Flutter Build Fails:**
```bash
flutter clean
flutter pub get
flutter doctor
flutter build apk --release
```

**Server Connection Issues:**
```bash
# Check firewall
ufw status
ufw allow 80
ufw allow 443

# Check services
docker-compose ps
systemctl status nginx
```

**Database Connection Errors:**
```bash
# Check database
docker exec maptag-postgres pg_isready -U maptag
# Reset if needed
docker-compose restart postgres
```

---

## 🎉 **You're Ready to Launch!**

**Everything is built and tested.** Your next commands:

```bash
# 1. Build the mobile app
cd frontend/maptag_bf && flutter build apk --release

# 2. Get a server and deploy
./scripts/deploy.sh production

# 3. Configure your domain and SSL

# 4. Launch! 🇧🇫
```

**MapTag BF is ready to revolutionize addressing in Burkina Faso!**