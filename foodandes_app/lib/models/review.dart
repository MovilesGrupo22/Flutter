class Review {
  final String id;
  final String restaurantId;
  final String userId;
  final String userName;
  final String comment;
  final int rating;
  final int timestamp;
  final List<String> imageUrls;

  const Review({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.rating,
    required this.timestamp,
    required this.imageUrls,
  });

  factory Review.fromFirestore(String id, Map<String, dynamic> data) {
    return Review(
      id: id,
      restaurantId: data['restaurantId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      comment: data['comment'] ?? '',
      rating: (data['rating'] ?? 0) is int
          ? data['rating'] ?? 0
          : ((data['rating'] ?? 0) as num).toInt(),
      timestamp: (data['timestamp'] ?? 0) is int
          ? data['timestamp'] ?? 0
          : ((data['timestamp'] ?? 0) as num).toInt(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }
}