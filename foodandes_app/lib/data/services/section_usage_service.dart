import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SectionUsageService {
  SectionUsageService._();
  static final SectionUsageService instance = SectionUsageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'section_usage';

  Future<void> recordSectionView(String section) async {
    try {
      await _firestore.collection(_collection).doc(section).set({
        'section': section,
        'viewCount': FieldValue.increment(1),
        'engagementScore': FieldValue.increment(1),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SectionUsage.recordSectionView ERROR -> $e');
    }
  }

  Future<void> recordSectionInteraction({
    required String section,
    required String action,
  }) async {
    try {
      await _firestore.collection(_collection).doc(section).set({
        'section': section,
        'interactionCount': FieldValue.increment(1),
        'engagementScore': FieldValue.increment(2),
        'lastAction': action,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SectionUsage.recordSectionInteraction ERROR -> $e');
    }
  }

  Stream<Map<String, dynamic>?> watchMostEngagedSection() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      Map<String, dynamic>? winner;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final score = (data['engagementScore'] as num?)?.toDouble() ?? 0;
        final winnerScore =
            (winner?['engagementScore'] as num?)?.toDouble() ?? -1;
        if (score > winnerScore) {
          winner = {
            'section': data['section'] ?? doc.id,
            'engagementScore': score,
            'viewCount': (data['viewCount'] as num?)?.toInt() ?? 0,
            'interactionCount': (data['interactionCount'] as num?)?.toInt() ?? 0,
          };
        }
      }
      return winner;
    });
  }

  Future<Map<String, dynamic>?> getMostEngagedSection() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      if (snapshot.docs.isEmpty) return null;

      Map<String, dynamic>? winner;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final score = (data['engagementScore'] as num?)?.toDouble() ?? 0;
        final winnerScore =
            (winner?['engagementScore'] as num?)?.toDouble() ?? -1;
        if (score > winnerScore) {
          winner = {
            'section': data['section'] ?? doc.id,
            'engagementScore': score,
            'viewCount': (data['viewCount'] as num?)?.toInt() ?? 0,
            'interactionCount': (data['interactionCount'] as num?)?.toInt() ?? 0,
          };
        }
      }
      return winner;
    } catch (e) {
      debugPrint('SectionUsage.getMostEngagedSection ERROR -> $e');
      return null;
    }
  }
}
