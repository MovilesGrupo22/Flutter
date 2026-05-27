import 'dart:convert';
import 'dart:io';

import 'package:foodandes_app/data/services/lru_cache.dart';
import 'package:foodandes_app/models/meal_plan.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MealPlanExportResult {
  final String fileName;
  final String filePath;
  final String format;
  final DateTime exportedAt;

  const MealPlanExportResult({
    required this.fileName,
    required this.filePath,
    required this.format,
    required this.exportedAt,
  });
}

class MealPlanFileExportService {
  MealPlanFileExportService._();

  static final MealPlanFileExportService instance =
      MealPlanFileExportService._();

  // Export payloads are deterministic for a saved plan. The LRU cache avoids
  // rebuilding the JSON/text payload when the user exports the same plan several
  // times during the same session.
  final LruCache<String, String> _payloadCache = LruCache(maxSize: 16);

  Future<MealPlanExportResult> exportAsJson(SavedMealPlan plan) async {
    final exportedAt = DateTime.now();
    final payload = _payloadFor(
      cacheKey: _cacheKey(plan, 'json'),
      builder: () => const JsonEncoder.withIndent('  ').convert(
        {
          'exportVersion': 1,
          'exportedAt': exportedAt.toIso8601String(),
          'source': 'FoodAndes saved meal plan',
          'plan': plan.toJson(),
        },
      ),
    );

    final fileName = '${_safeBaseFileName(plan)}.json';
    final filePath = await _writeExportFile(fileName, payload);

    return MealPlanExportResult(
      fileName: fileName,
      filePath: filePath,
      format: 'JSON',
      exportedAt: exportedAt,
    );
  }

  Future<MealPlanExportResult> exportAsText(SavedMealPlan plan) async {
    final exportedAt = DateTime.now();
    final payload = _payloadFor(
      cacheKey: _cacheKey(plan, 'txt'),
      builder: () => _buildHumanReadablePlan(plan, exportedAt),
    );

    final fileName = '${_safeBaseFileName(plan)}.txt';
    final filePath = await _writeExportFile(fileName, payload);

    return MealPlanExportResult(
      fileName: fileName,
      filePath: filePath,
      format: 'TXT',
      exportedAt: exportedAt,
    );
  }

  String _payloadFor({
    required String cacheKey,
    required String Function() builder,
  }) {
    final cached = _payloadCache.get(cacheKey);
    if (cached != null) return cached;

    final payload = builder();
    _payloadCache.put(cacheKey, payload);
    return payload;
  }

  Future<String> _writeExportFile(String fileName, String payload) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(path.join(documentsDir.path, 'meal_plan_exports'));

    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final file = File(path.join(exportsDir.path, fileName));
    await file.writeAsString(payload, flush: true);
    return file.path;
  }

  String _buildHumanReadablePlan(SavedMealPlan plan, DateTime exportedAt) {
    final buffer = StringBuffer()
      ..writeln('FoodAndes saved meal plan')
      ..writeln('Goal: ${plan.result.goal.label}')
      ..writeln('Saved at: ${plan.savedAt.toIso8601String()}')
      ..writeln('Exported at: ${exportedAt.toIso8601String()}');

    if (plan.result.selectedTags.isNotEmpty) {
      buffer.writeln('Selected tags: ${plan.result.selectedTags.join(', ')}');
    }

    buffer
      ..writeln('')
      ..writeln('Recommendations:');

    for (final recommendation in plan.result.recommendations) {
      buffer
        ..writeln('- ${recommendation.slotTitle}: ${recommendation.restaurant.name}')
        ..writeln('  Context: ${recommendation.slotSubtitle}')
        ..writeln('  Match score: ${recommendation.matchScore.toStringAsFixed(0)}')
        ..writeln('  Category: ${recommendation.restaurant.category}')
        ..writeln('  Price: ${recommendation.restaurant.priceRange}')
        ..writeln('  Rating: ${recommendation.restaurant.rating.toStringAsFixed(1)}')
        ..writeln('  Reasons: ${recommendation.reasons.join(', ')}')
        ..writeln('');
    }

    return buffer.toString();
  }

  String _safeBaseFileName(SavedMealPlan plan) {
    final goal = plan.result.goal.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final savedAt = plan.savedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    return 'foodandes_meal_plan_${goal}_$savedAt';
  }

  String _cacheKey(SavedMealPlan plan, String format) {
    return '${plan.id}:${plan.savedAt.millisecondsSinceEpoch}:$format';
  }
}
