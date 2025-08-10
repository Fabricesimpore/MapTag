# MapTag BF MVP Build Plan
*Step-by-step instructions for AI coding assistant*

## STEP 1: Project Setup & Architecture

### Backend Setup (Node.js + PostgreSQL)
```bash
# Create project structure
mkdir maptag-bf
cd maptag-bf
mkdir backend frontend

# Backend initialization
cd backend
npm init -y
npm install express postgres cors dotenv multer sharp geolib qrcode uuid bcrypt jsonwebtoken
npm install -D nodemon
```

### Database Schema (PostgreSQL)
```sql
-- Create tables
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE duplicate_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    address_id UUID REFERENCES addresses(id),
    reported_duplicate_id UUID REFERENCES addresses(id),
    distance_meters DECIMAL(8, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_addresses_location ON addresses USING GIST (point(longitude, latitude));
CREATE INDEX idx_addresses_code ON addresses(code);
```

## STEP 2: Backend API Development

### Core Backend Structure
```javascript
// server.js
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL
});

// Routes
app.use('/api/addresses', require('./routes/addresses'));
app.use('/api/verification', require('./routes/verification'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
```

### Address Generation Logic
```javascript
// utils/addressGenerator.js
function generateAddressCode(latitude, longitude, placeName) {
    // Grid system based on coordinates
    const latGrid = Math.floor((latitude + 90) * 100); // Convert to grid
    const lonGrid = Math.floor((longitude + 180) * 100);
    
    // Generate unique code: BF-CITY-GRID-XXXX
    const cityCode = determineCityCode(latitude, longitude);
    const gridCode = `${latGrid}${lonGrid}`.substring(0, 4);
    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    
    return `BF-${cityCode}-${gridCode}-${randomSuffix}`;
}

function determineCityCode(lat, lon) {
    // Ouagadougou: ~12.3714° N, 1.5197° W
    if (lat > 12.2 && lat < 12.5 && lon > -1.7 && lon < -1.3) return 'OUA';
    // Bobo-Dioulasso: ~11.1784° N, 4.2953° W  
    if (lat > 11.0 && lat < 11.3 && lon > -4.5 && lon < -4.0) return 'BOB';
    return 'OTH'; // Other
}

module.exports = { generateAddressCode };
```

### Duplicate Detection
```javascript
// utils/duplicateDetection.js
const geolib = require('geolib');

async function checkForDuplicates(pool, latitude, longitude, radius = 30) {
    const query = `
        SELECT id, code, place_name, latitude, longitude,
               earth_distance(point($1, $2), point(longitude, latitude)) as distance
        FROM addresses 
        WHERE earth_distance(point($1, $2), point(longitude, latitude)) <= $3
        ORDER BY distance;
    `;
    
    const result = await pool.query(query, [longitude, latitude, radius]);
    return result.rows;
}

module.exports = { checkForDuplicates };
```

## STEP 3: API Routes Implementation

### Address Routes
```javascript
// routes/addresses.js
const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const QRCode = require('qrcode');
const { generateAddressCode } = require('../utils/addressGenerator');
const { checkForDuplicates } = require('../utils/duplicateDetection');

const router = express.Router();
const upload = multer({ dest: 'uploads/temp/' });

// POST /api/addresses - Create new address
router.post('/', upload.single('photo'), async (req, res) => {
    try {
        const { latitude, longitude, placeName, category } = req.body;
        
        // Check for duplicates
        const duplicates = await checkForDuplicates(pool, parseFloat(latitude), parseFloat(longitude));
        
        if (duplicates.length > 0) {
            return res.status(409).json({
                error: 'Potential duplicate detected',
                duplicates: duplicates
            });
        }
        
        // Generate unique code
        const code = generateAddressCode(parseFloat(latitude), parseFloat(longitude), placeName);
        
        // Process and save photo
        let photoUrl = null;
        if (req.file) {
            const filename = `${code}_${Date.now()}.jpg`;
            await sharp(req.file.path)
                .resize(800, 600)
                .jpeg({ quality: 80 })
                .toFile(`uploads/${filename}`);
            photoUrl = `/uploads/${filename}`;
        }
        
        // Save to database
        const result = await pool.query(
            `INSERT INTO addresses (code, latitude, longitude, place_name, category, building_photo_url)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [code, latitude, longitude, placeName, category, photoUrl]
        );
        
        // Generate QR code
        const qrCodeUrl = await QRCode.toDataURL(`https://maptag.bf/${code}`);
        
        res.json({
            address: result.rows[0],
            qrCode: qrCodeUrl,
            shareUrl: `https://maptag.bf/${code}`
        });
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// GET /api/addresses/:code - Get address by code
router.get('/:code', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM addresses WHERE code = $1', [req.params.code]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Address not found' });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
```

## STEP 4: Flutter Mobile App Setup

### Project Initialization
```bash
cd ../frontend
flutter create maptag_bf
cd maptag_bf

# Add dependencies to pubspec.yaml
```

### Key Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  geolocator: ^9.0.2
  permission_handler: ^10.4.3
  camera: ^0.10.5+2
  image_picker: ^1.0.2
  qr_flutter: ^4.1.0
  barcode_scan2: ^4.2.3
  http: ^1.1.0
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  connectivity_plus: ^4.0.2
  uuid: ^3.0.7
  shared_preferences: ^2.2.0
```

## STEP 5: Flutter App Core Structure

### Main App Structure
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local database
  await DatabaseService.instance.database;
  
  runApp(MapTagApp());
}

class MapTagApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapTag BF',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Inter',
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Local Database Service
```dart
// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('maptag.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_addresses (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE,
        latitude REAL,
        longitude REAL,
        place_name TEXT,
        category TEXT,
        photo_path TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  Future<int> insertAddress(Map<String, dynamic> address) async {
    final db = await instance.database;
    return await db.insert('local_addresses', address);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAddresses() async {
    final db = await instance.database;
    return await db.query('local_addresses', where: 'synced = ?', whereArgs: [0]);
  }
}
```

## STEP 6: Core App Screens

### Home Screen
```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'create_address_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MapTag BF'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateAddressScreen()),
                  );
                },
                icon: Icon(Icons.add_location, size: 28),
                label: Text('Créer une Adresse', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
                icon: Icon(Icons.search, size: 28),
                label: Text('Rechercher Adresse', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Create Address Screen
```dart
// lib/screens/create_address_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../models/address_model.dart';
import 'dart:io';

class CreateAddressScreen extends StatefulWidget {
  @override
  _CreateAddressScreenState createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeNameController = TextEditingController();
  Position? _currentPosition;
  File? _selectedImage;
  String _selectedCategory = 'Résidence';
  bool _isLoading = false;

  final List<String> _categories = [
    'Résidence',
    'Commerce',
    'Bureau',
    'École',
    'Santé',
    'Restaurant',
    'Autre'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de géolocalisation: $e')),
      );
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _submitAddress() async {
    if (!_formKey.currentState!.validate() || _currentPosition == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final address = AddressModel(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        placeName: _placeNameController.text,
        category: _selectedCategory,
        photoPath: _selectedImage?.path,
      );

      final result = await ApiService.createAddress(address);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adresse créée: ${result['code']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer une Adresse'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_currentPosition != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Position: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _placeNameController,
                decoration: InputDecoration(
                  labelText: 'Nom du lieu *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Le nom du lieu est requis';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                          Text('Appuyez pour prendre une photo'),
                        ],
                      ),
              ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _takePicture,
                icon: Icon(Icons.camera),
                label: Text('Prendre une Photo'),
              ),
              Spacer(),
              Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAddress,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Créer l\'Adresse', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## STEP 7: Services & Models

### Location Service
```dart
// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<Position> getCurrentPosition() async {
    // Check permissions
    final permission = await Permission.location.request();
    if (permission.isDenied) {
      throw Exception('Permission de géolocalisation refusée');
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Services de géolocalisation désactivés');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
```

### Address Model
```dart
// lib/models/address_model.dart
class AddressModel {
  final String? id;
  final String? code;
  final double latitude;
  final double longitude;
  final String placeName;
  final String category;
  final String? photoPath;
  final DateTime? createdAt;

  AddressModel({
    this.id,
    this.code,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.category,
    this.photoPath,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'category': category,
      'photoPath': photoPath,
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      code: json['code'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      placeName: json['place_name'],
      category: json['category'],
      photoPath: json['photo_path'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
```

## STEP 8: API Service
```dart
// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/address_model.dart';

class ApiService {
  static const String baseUrl = 'http://your-server.com/api';
  
  static Future<Map<String, dynamic>> createAddress(AddressModel address) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/addresses'),
      );

      request.fields.addAll({
        'latitude': address.latitude.toString(),
        'longitude': address.longitude.toString(),
        'placeName': address.placeName,
        'category': address.category,
      });

      if (address.photoPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', address.photoPath!),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  static Future<AddressModel> getAddress(String code) async {
    final response = await http.get(
      Uri.parse('$baseUrl/addresses/$code'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AddressModel.fromJson(data);
    } else {
      throw Exception('Adresse non trouvée');
    }
  }
}
```

## STEP 9: Environment Setup & Deployment

### Environment Variables (.env)
```env
# Backend
DATABASE_URL=postgresql://username:password@localhost:5432/maptag_bf
PORT=3000
JWT_SECRET=your_jwt_secret_here

# API Keys (for future AI features)
GOOGLE_MAPS_API_KEY=your_google_maps_key
OPENAI_API_KEY=your_openai_key
```

### Docker Setup (docker-compose.yml)
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: maptag_bf
      POSTGRES_USER: maptag
      POSTGRES_PASSWORD: password123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports:
      - "3000:3000"
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgresql://maptag:password123@postgres:5432/maptag_bf

volumes:
  postgres_data:
```

## STEP 10: Testing & Launch

### Backend Testing
```bash
# Test API endpoints
curl -X POST http://localhost:3000/api/addresses \
  -F "latitude=12.3714" \
  -F "longitude=-1.5197" \
  -F "placeName=Test Location" \
  -F "category=Résidence"
```

### Flutter Testing
```bash
flutter test
flutter build apk --debug
```

### Deployment Checklist
- [ ] Set up PostgreSQL database
- [ ] Configure environment variables
- [ ] Deploy backend to cloud service (Railway, Heroku, etc.)
- [ ] Test API endpoints
- [ ] Build and test Flutter app
- [ ] Set up domain (maptag.bf)
- [ ] Configure SSL certificates
- [ ] Test offline functionality

## Next Steps After MVP
1. Implement AI verification using TensorFlow Lite
2. Add QR code scanning functionality
3. Implement offline sync mechanism
4. Add business features (Phase 2)
5. Create partner API (Phase 3)
6. Add mesh networking (Phase 4)

This MVP covers core address creation, GPS capture, photo upload, and basic sharing functionality. Start with this foundation and iterate based on user feedback.
