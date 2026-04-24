import 'package:flutter/foundation.dart';
import 'package:foodandes_app/models/review.dart';

class ReviewStats {
  final double average;
  final int total;
  final Map<int, int> distribution;

  const ReviewStats({
    required this.average,
    required this.total,
    required this.distribution,
  });

  factory ReviewStats.fromMap(Map<String, dynamic> map) {
    return ReviewStats(
      average: (map['average'] as num).toDouble(),
      total: map['total'] as int,
      distribution: Map<int, int>.from(map['distribution']),
    );
  }
}

Future<ReviewStats> computeReviewStats(List<Review> reviews) async {
  final rawReviews = reviews
      .map((review) => {
            'rating': review.rating,
          })
      .toList();

  final result = await compute(_calculateReviewStats, rawReviews);
  return ReviewStats.fromMap(result);
}

Map<String, dynamic> _calculateReviewStats(List<Map<String, dynamic>> reviews) {
  if (reviews.isEmpty) {
    return {
      'average': 0.0,
      'total': 0,
      'distribution': <int, int>{
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      },
    };
  }

  final distribution = <int, int>{
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 0,
  };

  var sum = 0;

  for (final review in reviews) {
    final rating = review['rating'] as int;
    sum += rating;
    distribution[rating] = (distribution[rating] ?? 0) + 1;
  }

  return {
    'average': sum / reviews.length,
    'total': reviews.length,
    'distribution': distribution,
  };
}