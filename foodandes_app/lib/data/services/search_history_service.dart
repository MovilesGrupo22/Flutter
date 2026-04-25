import 'package:foodandes_app/data/services/local_database_service.dart';

class SearchHistoryService {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();
  factory SearchHistoryService() => instance;

  final LocalDatabaseService _db = LocalDatabaseService.instance;

  Future<void> save(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await _db.insertSearchQuery(trimmed);
  }

  Future<List<String>> getAll() => _db.getSearchHistory();

  Future<void> delete(String query) => _db.deleteSearchQuery(query);

  Future<void> clear() => _db.clearSearchHistory();
}
