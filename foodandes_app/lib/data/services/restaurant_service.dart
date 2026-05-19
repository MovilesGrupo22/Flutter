import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/restaurant.dart';

// FIX #2 (app muy lenta):
// Sin caché, cada pantalla que necesita restaurantes lanzaba una lectura nueva
// a Firestore. Con un TTL de 60 segundos los datos se reutilizan en memoria
// durante la sesión y solo se refresca cuando realmente cambian.

class RestaurantService {
  RestaurantService._();
  static final RestaurantService instance = RestaurantService._();

  // Constructor de instancia para compatibilidad con código que usa
  // RestaurantService() directamente (RestaurantRepository, etc.).
  factory RestaurantService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Restaurant>? _cache;
  DateTime? _cacheTime;
  static const _ttl = Duration(seconds: 60);

  bool get _isCacheValid =>
      _cache != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _ttl;

  /// Devuelve todos los restaurantes. Usa caché en memoria (60 s de TTL).
  Future<List<Restaurant>> getRestaurants({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid) return _cache!;

    try {
      final snapshot = await _firestore
          .collection('restaurants')
          .get()
          .timeout(const Duration(seconds: 10));

      _cache = snapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc.id, doc.data()))
          .toList();
      _cacheTime = DateTime.now();
      return _cache!;
    } catch (e) {
      debugPrint('RestaurantService.getRestaurants ERROR -> $e');
      // Devuelve caché vieja si hay, en lugar de lanzar
      return _cache ?? [];
    }
  }

  /// Busca un restaurante por id. Usa la caché si está disponible.
  Future<Restaurant?> getRestaurantById(String restaurantId) async {
    // Intenta encontrarlo en caché primero (evita una lectura extra)
    if (_isCacheValid) {
      try {
        return _cache!.firstWhere((r) => r.id == restaurantId);
      } catch (_) {
        // no encontrado en caché, sigue con Firestore
      }
    }

    try {
      final doc = await _firestore
          .collection('restaurants')
          .doc(restaurantId)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) return null;
      return Restaurant.fromFirestore(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('RestaurantService.getRestaurantById ERROR -> $e');
      return null;
    }
  }

  /// Invalida la caché (llamar tras escribir favoritos, reseñas, etc.)
  void invalidateCache() {
    _cache = null;
    _cacheTime = null;
  }
}
