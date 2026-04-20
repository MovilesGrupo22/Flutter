import 'dart:math';

import 'package:foodandes_app/models/restaurant.dart';

class CompareRecommendation {
  final Restaurant winner;
  final double leftScore;
  final double rightScore;
  final String label;
  final String summary;
  final List<String> reasons;

  const CompareRecommendation({
    required this.winner,
    required this.leftScore,
    required this.rightScore,
    required this.label,
    required this.summary,
    required this.reasons,
  });
}

class CompareDecisionService {
  CompareDecisionService._();

  static final CompareDecisionService instance = CompareDecisionService._();

  CompareRecommendation recommend({
    required Restaurant left,
    required Restaurant right,
  }) {
    final leftScore = _score(left);
    final rightScore = _score(right);

    final winner = leftScore >= rightScore ? left : right;
    final loser = winner.id == left.id ? right : left;

    final difference = (leftScore - rightScore).abs();
    final label = difference >= 2.5 ? 'Best overall option' : 'Very close match';

    final reasons = _buildReasons(winner: winner, loser: loser);

    final summary = difference >= 2.5
        ? '${winner.name} stands out as the strongest choice right now.'
        : '${winner.name} has a slight edge, but both restaurants are competitive.';

    return CompareRecommendation(
      winner: winner,
      leftScore: leftScore,
      rightScore: rightScore,
      label: label,
      summary: summary,
      reasons: reasons,
    );
  }

  double _score(Restaurant restaurant) {
    double score = 0;

    if (restaurant.isOpen) score += 3.0;
    score += restaurant.rating * 2.0;
    score += min(restaurant.reviewCount / 5.0, 2.5);
    score += _priceValue(restaurant.priceRange);

    final normalizedTags = restaurant.tags.map((tag) => tag.toLowerCase()).toList();

    if (normalizedTags.any((tag) =>
        tag.contains('lunch') ||
        tag.contains('traditional') ||
        tag.contains('healthy') ||
        tag.contains('brunch') ||
        tag.contains('fast food'))) {
      score += 1.0;
    }

    return score;
  }

  double _priceValue(String priceRange) {
    switch (priceRange) {
      case r'$':
        return 3.0;
      case r'$$':
        return 2.0;
      case r'$$$':
        return 1.0;
      default:
        return 0.0;
    }
  }

  List<String> _buildReasons({
    required Restaurant winner,
    required Restaurant loser,
  }) {
    final reasons = <String>[];

    if (winner.isOpen && !loser.isOpen) {
      reasons.add('Open now');
    }

    if (winner.rating > loser.rating) {
      reasons.add('Higher rating');
    }

    if (winner.reviewCount > loser.reviewCount) {
      reasons.add('More reviews');
    }

    if (_priceValue(winner.priceRange) > _priceValue(loser.priceRange)) {
      reasons.add('Better price value');
    }

    final winnerTags = winner.tags.map((tag) => tag.toLowerCase()).join(' ');
    if (winnerTags.contains('healthy')) {
      reasons.add('Good healthy option');
    } else if (winnerTags.contains('traditional') || winnerTags.contains('casero')) {
      reasons.add('Good comfort-food pick');
    } else if (winnerTags.contains('lunch') || winnerTags.contains('brunch')) {
      reasons.add('Strong meal-time match');
    }

    if (reasons.isEmpty) {
      reasons.add('Better overall score');
    }

    return reasons.take(3).toList();
  }
}
