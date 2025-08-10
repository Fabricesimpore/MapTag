# MapTag BF - Digital Addressing System for Burkina Faso

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)](https://flutter.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue.svg)](https://postgresql.org/)

MapTag BF is a comprehensive digital addressing system designed specifically for Burkina Faso. It enables users to create, share, and verify digital addresses with GPS coordinates, photos, and unique codes that work both online and offline.

## 🎯 Vision

Give every home, shop, and service point in Burkina Faso a permanent, digital address that works offline or online and can be used for deliveries, transport, and emergency services.

## ✨ Features

### Core Functionality
- **GPS-based Address Creation**: Capture precise location coordinates
- **Photo Verification**: Take building photos for address verification
- **Unique Address Codes**: Generate memorable codes (BF-CITY-GRID-XXXX format)
- **Offline Support**: Create and store addresses offline, sync when online
- **Duplicate Detection**: AI-powered duplicate address prevention
- **QR Code Generation**: Easy sharing via QR codes

### Categories Supported
- Résidences (Homes)
- Commerce (Businesses)
- Bureaux (Offices)
- Écoles (Schools)
- Santé (Health facilities)
- Restaurants
- Other locations

### Technical Features
- RESTful API with comprehensive endpoints
- Real-time duplicate detection
- Geospatial queries with PostGIS
- Image processing and optimization
- Multi-language support (French/Local languages)
- Rate limiting and security measures

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│   Nginx      │◄──►│   Backend API   │
│   (Mobile)      │    │   (Proxy)    │    │   (Node.js)     │
└─────────────────┘    └──────────────┘    └─────────────────┘
         │                                           │
         ▼                                           ▼
┌─────────────────┐                        ┌─────────────────┐
│   SQLite        │                        │   PostgreSQL    │
│   (Local DB)    │                        │   + PostGIS     │
└─────────────────┘                        └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 18+ (for development)
- Flutter SDK 3.10+ (for mobile app development)
- PostgreSQL 15+ with PostGIS (if running without Docker)

### Using Docker (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd maptag-bf
   ```

2. **Start all services**
   ```bash
   docker-compose up -d
   ```

3. **Verify services are running**
   ```bash
   curl http://localhost:3000/health
   ```

The following services will be available:
- **API Server**: http://localhost:3000
- **Database**: localhost:5432
- **Redis**: localhost:6379
- **Web Interface**: http://localhost:80

### Manual Setup

#### Backend Setup

1. **Install dependencies**
   ```bash
   cd backend
   npm install
   ```

2. **Set up environment**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

3. **Set up PostgreSQL database**
   ```sql
   createdb maptag_bf
   psql maptag_bf < database.sql
   ```

4. **Start the server**
   ```bash
   npm run dev
   ```

#### Flutter App Setup

1. **Install Flutter dependencies**
   ```bash
   cd frontend/maptag_bf
   flutter pub get
   ```

2. **Run the app**
   ```bash
   flutter run
   ```

## 📱 API Documentation

### Address Endpoints

#### Create Address
```http
POST /api/addresses
Content-Type: multipart/form-data

latitude: 12.3714
longitude: -1.5197
placeName: "Maison Ouédraogo"
category: "Résidence"
photo: [file]
```

#### Get Address
```http
GET /api/addresses/{code}
```

#### Search Addresses
```http
GET /api/addresses?search=Ouédraogo&category=Résidence&page=1&limit=20
```

#### Report Duplicate
```http
POST /api/addresses/{code}/report-duplicate
Content-Type: application/json

{
  "duplicate_code": "BF-OUA-1234-ABCD",
  "reason": "Same building"
}
```

### Verification Endpoints

#### Get Verification Queue
```http
GET /api/verification/queue?status=pending&limit=50
```

#### Process Verification
```http
POST /api/verification/{queueId}/process
Content-Type: application/json

{
  "action": "approve",
  "confidence_score": 95,
  "notes": "Verified by agent"
}
```

### Response Format

All API responses follow this format:
```json
{
  "success": true,
  "data": { /* response data */ },
  "message": "Operation successful"
}
```

Error responses:
```json
{
  "error": "Error description",
  "details": { /* additional error details */ },
  "statusCode": 400
}
```

## 🗄️ Database Schema

### Main Tables

#### addresses
- `id` - UUID primary key
- `code` - Unique address code (BF-CITY-GRID-XXXX)
- `latitude/longitude` - GPS coordinates
- `place_name` - Human-readable name
- `category` - Address category
- `building_photo_url` - Photo URL
- `confidence_score` - Verification confidence (0-100)
- `verification_status` - pending/verified/rejected/flagged
- `geom` - PostGIS geometry point

#### duplicate_reports
- `id` - UUID primary key
- `address_id` - Address being reported
- `reported_duplicate_id` - Potential duplicate
- `distance_meters` - Distance between addresses

#### verification_queue
- `id` - UUID primary key
- `address_id` - Address to verify
- `verification_type` - Type of verification needed
- `status` - pending/processing/completed/failed
- `ai_confidence` - AI confidence score

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/maptag_bf

# Application
NODE_ENV=development
PORT=3000
JWT_SECRET=your-secret-key

# File uploads
MAX_FILE_SIZE=5242880  # 5MB
UPLOAD_PATH=./uploads

# External APIs
GOOGLE_MAPS_API_KEY=your-key-here
```

### Docker Compose Overrides

Create `docker-compose.override.yml` for local customizations:

```yaml
version: '3.8'
services:
  backend:
    environment:
      NODE_ENV: development
    volumes:
      - ./backend:/app
      - /app/node_modules
```

## 🧪 Testing

### Backend Tests
```bash
cd backend
npm test
```

### Flutter Tests
```bash
cd frontend/maptag_bf
flutter test
```

### API Testing
```bash
# Test address creation
curl -X POST http://localhost:3000/api/addresses \
  -F "latitude=12.3714" \
  -F "longitude=-1.5197" \
  -F "placeName=Test Location" \
  -F "category=Résidence"

# Test health endpoint
curl http://localhost:3000/health
```

## 🚀 Deployment

### Production Deployment

1. **Update environment variables**
   ```bash
   cp .env.example .env.production
   # Update with production values
   ```

2. **Build and deploy**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **Set up SSL certificates** (recommended)
   ```bash
   # Using Let's Encrypt
   certbot --nginx -d maptag.bf
   ```

### Environment-Specific Configurations

- **Development**: Full logging, debug mode enabled
- **Staging**: Production-like setup for testing
- **Production**: Optimized for performance and security

## 📊 Monitoring

### Health Checks
- `/health` - Application health status
- `/api/verification/stats` - Verification statistics

### Logging
- Application logs: `/var/log/maptag/app.log`
- Nginx logs: `/var/log/nginx/`
- Database logs: PostgreSQL standard logging

### Metrics
- Address creation rate
- Verification success rate
- API response times
- Database performance

## 🔒 Security

### Implemented Security Measures
- Rate limiting on API endpoints
- Input validation and sanitization
- SQL injection prevention with parameterized queries
- File upload restrictions and validation
- CORS configuration
- Security headers via Nginx
- Non-root container execution

### Security Considerations
- Change default JWT secret in production
- Use HTTPS in production
- Regular security updates for dependencies
- Database access controls
- API key management

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Code Style
- Backend: ESLint with Airbnb configuration
- Flutter: Official Dart style guide
- Database: PostgreSQL naming conventions

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- PostGIS for geospatial capabilities
- Flutter team for mobile framework
- Node.js community for backend tools
- OpenStreetMap for map data

## 📞 Support

- Issues: GitHub Issues
- Email: support@maptag.bf
- Documentation: [docs.maptag.bf](https://docs.maptag.bf)

---

**MapTag BF** - Digitizing addresses across Burkina Faso, one location at a time.