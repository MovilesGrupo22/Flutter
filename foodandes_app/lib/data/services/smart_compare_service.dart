import 'dart:math' as math;
import 'package:foodandes_app/models/restaurant.dart';

/// Result produced by [SmartCompareService.compare].
class SmartCompareResult {
  /// Normalised score 0–100 for the left (base) restaurant.
  final double leftScore;

  /// Normalised score 0–100 for the right (selected) restaurant.
  final double rightScore;

  /// 'left' | 'right' | 'tie'
  final String winner;

  /// Natural-language recommendation shown to the user.
  final String verdict;

  /// Key advantages of the left restaurant over the right one.
  final List<String> leftStrengths;

  /// Key advantages of the right restaurant over the left one.
  final List<String> rightStrengths;

  const SmartCompareResult({
    required this.leftScore,
    required this.rightScore,
    required this.winner,
    required this.verdict,
    required this.leftStrengths,
    required this.rightStrengths,
  });

  /// True when the two restaurants are too close to call.
  bool get isTie => winner == 'tie';

  Restaurant? winnerRestaurant(Restaurant left, Restaurant right) {
    if (isTie) return null;
    return winner == 'left' ? left : right;
  }
}

/// Context-aware scoring engine for comparing two restaurants.
///
/// Dimensions and weights:
///   Rating          40 % — most reliable quality signal
///   Popularity      20 % — log-scaled review count (credibility)
///   Price-value     15 % — fewer dollar signs → higher score
///   Open now        15 % — strong contextual bonus
///   Tag richness    10 % — menu/experience variety
class SmartCompareService {
  SmartCompareService._();
  static final SmartCompareService instance = SmartCompareService._();

  static const double _ratingW = 0.40;
  static const double _popularityW = 0.20;
  static const double _priceW = 0.15;
  static const double _openW = 0.15;
  static const double _tagW = 0.10;

  // The denominator for the popularity log-scale.
  // ~500 reviews ≈ a very popular campus restaurant.
  static const double _reviewCeiling = 500;

  // Margin under which we declare a tie (out of 100).
  static const double _tieTolerance = 3.0;

  // ─── Public API ────────────────────────────────────────────────────────────

  SmartCompareResult compare(Restaurant left, Restaurant right) {
    final ls = _score(left);
    final rs = _score(right);

    final diff = ls - rs;
    final String winner;
    if (diff.abs() < _tieTolerance) {
      winner = 'tie';
    } else if (diff > 0) {
      winner = 'left';
    } else {
      winner = 'right';
    }

    return SmartCompareResult(
      leftScore: ls,
      rightScore: rs,
      winner: winner,
      verdict: _buildVerdict(left, right, ls, rs, winner),
      leftStrengths: _strengths(left, right),
      rightStrengths: _strengths(right, left),
    );
  }

  // ─── Scoring ───────────────────────────────────────────────────────────────

  double _score(Restaurant r) {
    double score = 0;

    // 1. Rating (0–5 → 0–100)
    score += (r.rating / 5.0) * 100 * _ratingW;

    // 2. Popularity – log scale so 500+ reviews ≈ 100 pts
    final reviewScore = r.reviewCount > 0
        ? (math.log(r.reviewCount) / math.log(_reviewCeiling))
            .clamp(0.0, 1.0) *
            100
        : 0.0;
    score += reviewScore * _popularityW;

    // 3. Price-value ($ = 100, $$$$ = 25)
    score += _priceScore(r.priceRange) * _priceW;

    // 4. Open right now
    score += (r.isOpen ? 100.0 : 0.0) * _openW;

    // 5. Tag richness (5+ tags → full marks)
    final tagScore = (r.tags.length / 5.0).clamp(0.0, 1.0) * 100;
    score += tagScore * _tagW;

    return score.clamp(0.0, 100.0);
  }

  double _priceScore(String priceRange) {
    switch (priceRange.trim()) {
      case r'$':
        return 100;
      case r'$$':
        return 75;
      case r'$$$':
        return 50;
      case r'$$$$':
        return 25;
      default:
        return 60;
    }
  }

  // ─── Strengths ─────────────────────────────────────────────────────────────

  List<String> _strengths(Restaurant a, Restaurant b) {
    final s = <String>[];

    if (a.rating > b.rating) {
      s.add(
          '⭐ Better rated  ${a.rating.toStringAsFixed(2)} vs ${b.rating.toStringAsFixed(2)}');
    }
    if (a.reviewCount > b.reviewCount * 1.2) {
      s.add('💬 More reviews  (${a.reviewCount} vs ${b.reviewCount})');
    }
    if (_priceScore(a.priceRange) > _priceScore(b.priceRange)) {
      s.add('💰 Better value  (${a.priceRange} vs ${b.priceRange})');
    }
    if (a.isOpen && !b.isOpen) {
      s.add('🟢 Open right now');
    }
    if (a.tags.length > b.tags.length + 1) {
      s.add('🏷️ More variety  (${a.tags.length} options)');
    }

    return s;
  }

  // ─── Verdict ───────────────────────────────────────────────────────────────

  String _buildVerdict(
    Restaurant left,
    Restaurant right,
    double ls,
    double rs,
    String winner,
  ) {
    if (winner == 'tie') {
      return '${left.name} and ${right.name} are extremely evenly matched — '
          'you really can\'t go wrong with either! Consider which is closer '
          'or currently open.';
    }

    final w = winner == 'left' ? left : right;
    final l = winner == 'left' ? right : left;
    final diff = (ls - rs).abs();

    if (diff < 10) {
      return '${w.name} edges ahead by a thin margin. Both restaurants are '
          'excellent choices, but ${w.name} has a slight advantage in '
          'rating and value.';
    } else if (diff < 25) {
      return '${w.name} is the stronger option here. It outperforms '
          '${l.name} across multiple dimensions — particularly quality '
          'and popularity among diners.';
    } else {
      return '${w.name} is the clear winner! It significantly outscores '
          '${l.name} in most categories. We recommend heading to '
          '${w.name} for your next meal.';
    }
  }
}
