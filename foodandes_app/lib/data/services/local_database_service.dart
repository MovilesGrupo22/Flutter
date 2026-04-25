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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE restaurants (
            id TEXT PRIMARY KEY,
            name TEXT,
            category TEXT,
            rating REAL,
            price_range TEXT,
            is_open INTEGER,
            image_url TEXT,
            address TEXT,
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
        await db.execute('''
          CREATE TABLE search_history (
            query TEXT PRIMARY KEY,
            searched_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS search_history (
              query TEXT PRIMARY KEY,
              searched_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
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
          'rating': r.rating,
          'price_range': r.priceRange,
          'is_open': r.isOpen ? 1 : 0,
          'image_url': r.imageURL,
          'address': r.address,
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
        description: '',
        imageURL: row['image_url'] as String? ?? '',
        isOpen: (row['is_open'] as int? ?? 0) == 1,
        latitude: 0.0,
        longitude: 0.0,
        openingHours: '',
        priceRange: row['price_range'] as String? ?? '',
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: 0,
        tags: tags,
        address: row['address'] as String? ?? '',
        phone: '',
      );
    }).toList();
  }

  Future<void> insertFavorite(String userId, String restaurantId) async {
    final db = await _database;
    await db.insert(
      'user_favorites',
      {'user_id': userId, 'restaurant_id': restaurantId},
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
      description: '',
      imageURL: row['image_url'] as String? ?? '',
      isOpen: (row['is_open'] as int? ?? 0) == 1,
      latitude: 0.0,
      longitude: 0.0,
      openingHours: '',
      priceRange: row['price_range'] as String? ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: 0,
      tags: tags,
      address: row['address'] as String? ?? '',
      phone: '',
    );
  }

  Future<void> clearRestaurants() async {
    final db = await _database;
    await db.delete('restaurants');
  }

  Future<void> insertSearchQuery(String query) async {
    final db = await _database;
    await db.insert(
      'search_history',
      {'query': query, 'searched_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Keep only the 10 most recent unique queries
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
}
