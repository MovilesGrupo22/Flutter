import 'package:cloud_firestore/cloud_firestore.dart';

class PopularFiltersService {
  PopularFiltersService._();
  static final PopularFiltersService instance = PopularFiltersService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'filter_usage';

  // Incrementa el contador cuando alguien usa un filtro
  Future<void> incrementFilter({
    required String filterType,  // 'price_range', 'category', 'quick_chip'
    required String filterValue, // '$$$', 'Comida', 'Open', etc.
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(filterType)
          .set(
            {filterValue: FieldValue.increment(1)},
            SetOptions(merge: true), // no sobreescribe otros campos
          );
    } catch (e) {
      // Si falla, no rompemos la app — el filtro igual se aplica
    }
  }

  // Devuelve los N filtros más usados de un tipo
  Future<List<String>> getTopFilters({
    required String filterType,
    int topN = 3,
  }) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(filterType)
          .get();

      if (!doc.exists || doc.data() == null) return [];

      final data = doc.data()!;

      // Ordena por conteo descendente y toma los primeros N
      final sorted = data.entries
          .where((e) => e.key != 'All') // excluimos "All"
          .toList()
        ..sort((a, b) => (b.value as int).compareTo(a.value as int));

      return sorted.take(topN).map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }
}