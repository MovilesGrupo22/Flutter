import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteSourceService {
  FavoriteSourceService._();

  static final FavoriteSourceService instance = FavoriteSourceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'favorite_source_usage';

  Future<void> recordFavoriteSource(String source) async {
    try {
      await _firestore.collection(_collection).doc(source).set({
        'source': source,
        'count': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {
      // do not block favorite flow
    }
  }

  Stream<Map<String, dynamic>?> watchTopFavoriteSource() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .handleError((_) {})
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      Map<String, dynamic>? winner;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final count = (data['count'] as num?)?.toInt() ?? 0;
        final winnerCount = (winner?['count'] as num?)?.toInt() ?? -1;
        if (count > winnerCount) {
          winner = {
            'source': data['source'] ?? doc.id,
            'count': count,
          };
        }
      }
      return winner;
    });
  }
}
