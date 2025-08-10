import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/address_model.dart';

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
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Local addresses table for offline storage
    await db.execute('''
      CREATE TABLE local_addresses (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        place_name TEXT NOT NULL,
        category TEXT NOT NULL,
        photo_path TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address_id TEXT,
        action TEXT NOT NULL,
        data TEXT,
        attempts INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (address_id) REFERENCES local_addresses (id)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_local_addresses_code ON local_addresses(code)');
    await db.execute('CREATE INDEX idx_local_addresses_synced ON local_addresses(synced)');
    await db.execute('CREATE INDEX idx_sync_queue_action ON sync_queue(action)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    if (oldVersion < newVersion) {
      // Add upgrade logic for future versions
    }
  }

  // Address operations
  Future<String> insertAddress(AddressModel address) async {
    final db = await instance.database;
    final id = address.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final data = address.toLocalDb();
    data['id'] = id;
    
    await db.insert('local_addresses', data, 
        conflictAlgorithm: ConflictAlgorithm.replace);
    
    return id;
  }

  Future<List<AddressModel>> getAllAddresses() async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      orderBy: 'created_at DESC',
    );
    
    return result.map((map) => AddressModel.fromLocalDb(map)).toList();
  }

  Future<AddressModel?> getAddressById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (result.isNotEmpty) {
      return AddressModel.fromLocalDb(result.first);
    }
    return null;
  }

  Future<AddressModel?> getAddressByCode(String code) async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      where: 'code = ?',
      whereArgs: [code],
    );
    
    if (result.isNotEmpty) {
      return AddressModel.fromLocalDb(result.first);
    }
    return null;
  }

  Future<List<AddressModel>> getUnsyncedAddresses() async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    
    return result.map((map) => AddressModel.fromLocalDb(map)).toList();
  }

  Future<void> markAddressSynced(String id, String? serverCode) async {
    final db = await instance.database;
    final updateData = {
      'synced': 1,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (serverCode != null) {
      updateData['code'] = serverCode;
    }
    
    await db.update(
      'local_addresses',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAddress(String id, Map<String, dynamic> updates) async {
    final db = await instance.database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    updates['synced'] = 0; // Mark as needing sync
    
    await db.update(
      'local_addresses',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAddress(String id) async {
    final db = await instance.database;
    await db.delete(
      'local_addresses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sync queue operations
  Future<void> addToSyncQueue(String action, String? addressId, [Map<String, dynamic>? data]) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'address_id': addressId,
      'action': action,
      'data': data != null ? data.toString() : null,
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> removeSyncQueueItem(int id) async {
    final db = await instance.database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementSyncAttempts(int id) async {
    final db = await instance.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?',
      [id],
    );
  }

  // Search operations
  Future<List<AddressModel>> searchAddresses(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      where: 'place_name LIKE ? OR code LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    
    return result.map((map) => AddressModel.fromLocalDb(map)).toList();
  }

  Future<List<AddressModel>> getAddressesByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'local_addresses',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    
    return result.map((map) => AddressModel.fromLocalDb(map)).toList();
  }

  // Statistics
  Future<Map<String, int>> getAddressStats() async {
    final db = await instance.database;
    
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM local_addresses');
    final syncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM local_addresses WHERE synced = 1');
    final unsyncedResult = await db.rawQuery('SELECT COUNT(*) as count FROM local_addresses WHERE synced = 0');
    
    return {
      'total': totalResult.first['count'] as int,
      'synced': syncedResult.first['count'] as int,
      'unsynced': unsyncedResult.first['count'] as int,
    };
  }

  // Cleanup operations
  Future<void> clearSyncedAddresses() async {
    final db = await instance.database;
    await db.delete(
      'local_addresses',
      where: 'synced = ?',
      whereArgs: [1],
    );
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('local_addresses');
    await db.delete('sync_queue');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}