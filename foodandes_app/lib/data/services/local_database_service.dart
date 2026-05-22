import 'dart:convert';

import 'package:foodandes_app/models/restaurant.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();
  factory LocalDatabaseService() => instance;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'restaurandes.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE restaurants (
            id TEXT PRIMARY KEY,
            name TEXT,
            category TEXT,
            description TEXT,
            rating REAL,
            review_count INTEGER,
            price_range TEXT,
            is_open INTEGER,
            image_url TEXT,
            latitude REAL,
            longitude REAL,
            opening_hours TEXT,
            address TEXT,
            phone TEXT,
            tags_json TEXT,
            cached_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE user_favorites (
            user_id TEXT,
            restaurant_id TEXT,
            PRIMARY KEY(user_id, restaurant_id)
          )
        ''');

        await _createSearchHistoryTable(db);
        await _createPendingReviewsTable(db);
        await _createRecentlyViewedTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSearchHistoryTable(db);
          await _createPendingReviewsTable(db);
        }
        if (oldVersion < 3) {
          await _createRecentlyViewedTable(db);
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(db, 'restaurants', 'description', 'TEXT');
          await _addColumnIfMissing(db, 'restaurants', 'review_count', 'INTEGER');
          await _addColumnIfMissing(db, 'restaurants', 'latitude', 'REAL');
          await _addColumnIfMissing(db, 'restaurants', 'longitude', 'REAL');
          await _addColumnIfMissing(db, 'restaurants', 'opening_hours', 'TEXT');
          await _addColumnIfMissing(db, 'restaurants', 'phone', 'TEXT');
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _createSearchHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS search_history (
        query TEXT PRIMARY KEY,
        searched_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createPendingReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        restaurant_id TEXT NOT NULL,
        restaurant_name TEXT,
        comment TEXT NOT NULL,
        rating INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retries INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createRecentlyViewedTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recently_viewed (
        restaurant_id TEXT PRIMARY KEY,
        viewed_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> insertRestaurants(List<Restaurant> restaurants) async {
    final db = await _database;
    final batch = db.batch();

    for (final r in restaurants) {
      batch.insert(
        'restaurants',
        {
          'id': r.id,
          'name': r.name,
          'category': r.category,
          'description': r.description,
          'rating': r.rating,
          'review_count': r.reviewCount,
          'price_range': r.priceRange,
          'is_open': r.isOpen ? 1 : 0,
          'image_url': r.imageURL,
          'latitude': r.latitude,
          'longitude': r.longitude,
          'opening_hours': r.openingHours,
          'address': r.address,
          'phone': r.phone,
          'tags_json': jsonEncode(r.tags),
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Restaurant>> getRestaurants() async {
    final db = await _database;
    final rows = await db.query('restaurants');

    return rows.map((row) {
      final tagsJson = row['tags_json'] as String? ?? '[]';
      final tags = (jsonDecode(tagsJson) as List).cast<String>();

      return Restaurant(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        category: row['category'] as String? ?? '',
        description: row['description'] as String? ?? '',
        imageURL: row['image_url'] as String? ?? '',
        isOpen: (row['is_open'] as int? ?? 0) == 1,
        latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
        openingHours: row['opening_hours'] as String? ?? '',
        priceRange: row['price_range'] as String? ?? '',
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
        tags: tags,
        address: row['address'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
      );
    }).toList();
  }

  Future<Restaurant?> getRestaurantById(String id) async {
    final db = await _database;
    final rows = await db.query(
      'restaurants',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final tagsJson = row['tags_json'] as String? ?? '[]';
    final tags = (jsonDecode(tagsJson) as List).cast<String>();

    return Restaurant(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      category: row['category'] as String? ?? '',
      description: row['description'] as String? ?? '',
      imageURL: row['image_url'] as String? ?? '',
      isOpen: (row['is_open'] as int? ?? 0) == 1,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
      openingHours: row['opening_hours'] as String? ?? '',
      priceRange: row['price_range'] as String? ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
      tags: tags,
      address: row['address'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
    );
  }

  Future<void> clearRestaurants() async {
    final db = await _database;
    await db.delete('restaurants');
  }

  Future<void> insertFavorite(String userId, String restaurantId) async {
    final db = await _database;

    await db.insert(
      'user_favorites',
      {
        'user_id': userId,
        'restaurant_id': restaurantId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeFavorite(String userId, String restaurantId) async {
    final db = await _database;

    await db.delete(
      'user_favorites',
      where: 'user_id = ? AND restaurant_id = ?',
      whereArgs: [userId, restaurantId],
    );
  }

  Future<List<String>> getFavoriteIds(String userId) async {
    final db = await _database;

    final rows = await db.query(
      'user_favorites',
      columns: ['restaurant_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return rows.map((r) => r['restaurant_id'] as String).toList();
  }

  Future<void> replaceFavoriteIds(String userId, List<String> restaurantIds) async {
    final db = await _database;
    final batch = db.batch();

    batch.delete(
      'user_favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final restaurantId in restaurantIds.toSet()) {
      batch.insert(
        'user_favorites',
        {
          'user_id': userId,
          'restaurant_id': restaurantId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> insertSearchQuery(String query) async {
    final db = await _database;

    await db.insert(
      'search_history',
      {
        'query': query,
        'searched_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.rawDelete('''
      DELETE FROM search_history
      WHERE query NOT IN (
        SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 10
      )
    ''');
  }

  Future<List<String>> getSearchHistory() async {
    final db = await _database;

    final rows = await db.query(
      'search_history',
      columns: ['query'],
      orderBy: 'searched_at DESC',
      limit: 10,
    );

    return rows.map((r) => r['query'] as String).toList();
  }

  Future<void> deleteSearchQuery(String query) async {
    final db = await _database;

    await db.delete(
      'search_history',
      where: 'query = ?',
      whereArgs: [query],
    );
  }

  Future<void> clearSearchHistory() async {
    final db = await _database;
    await db.delete('search_history');
  }

  Future<void> recordRecentlyViewed(Restaurant restaurant) async {
    final db = await _database;

    await insertRestaurants([restaurant]);

    await db.insert(
      'recently_viewed',
      {
        'restaurant_id': restaurant.id,
        'viewed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.rawDelete('''
      DELETE FROM recently_viewed
      WHERE restaurant_id NOT IN (
        SELECT restaurant_id FROM recently_viewed
        ORDER BY viewed_at DESC
        LIMIT 20
      )
    ''');
  }

  Future<List<Restaurant>> getRecentlyViewedRestaurants() async {
    final db = await _database;

    final rows = await db.rawQuery('''
      SELECT r.*
      FROM recently_viewed rv
      INNER JOIN restaurants r ON r.id = rv.restaurant_id
      ORDER BY rv.viewed_at DESC
      LIMIT 20
    ''');

    return rows.map((row) {
      final tagsJson = row['tags_json'] as String? ?? '[]';
      final tags = (jsonDecode(tagsJson) as List).cast<String>();

      return Restaurant(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        category: row['category'] as String? ?? '',
        description: row['description'] as String? ?? '',
        imageURL: row['image_url'] as String? ?? '',
        isOpen: (row['is_open'] as int? ?? 0) == 1,
        latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
        openingHours: row['opening_hours'] as String? ?? '',
        priceRange: row['price_range'] as String? ?? '',
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (row['review_count'] as num?)?.toInt() ?? 0,
        tags: tags,
        address: row['address'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> clearRecentlyViewed() async {
    final db = await _database;
    await db.delete('recently_viewed');
  }

  Future<void> insertPendingReview({
    required String restaurantId,
    required String restaurantName,
    required String comment,
    required int rating,
    required String userName,
  }) async {
    final db = await _database;

    await db.insert('pending_reviews', {
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'comment': comment,
      'rating': rating,
      'user_name': userName,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingReviews() async {
    final db = await _database;

    return db.query(
      'pending_reviews',
      orderBy: 'created_at ASC',
    );
  }

  Future<void> deletePendingReview(int id) async {
    final db = await _database;

    await db.delete(
      'pending_reviews',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementPendingReviewRetries(int id) async {
    final db = await _database;

    await db.rawUpdate(
      'UPDATE pending_reviews SET retries = retries + 1 WHERE id = ?',
      [id],
    );
  }
}
