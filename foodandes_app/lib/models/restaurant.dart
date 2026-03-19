class Restaurant {
  final String id;
  final String name;
  final String category;
  final String description;
  final String imageURL;
  final bool isOpen;
  final double latitude;
  final double longitude;
  final String openingHours;
  final String priceRange;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String address;
  final String phone;
  final bool isFavorite;

  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageURL,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.priceRange,
    required this.rating,
    required this.reviewCount,
    required this.tags,
    required this.address,
    required this.phone,
    this.isFavorite = false,
  });

  Restaurant copyWith({
    bool? isFavorite,
  }) {
    return Restaurant(
      id: id,
      name: name,
      category: category,
      description: description,
      imageURL: imageURL,
      isOpen: isOpen,
      latitude: latitude,
      longitude: longitude,
      openingHours: openingHours,
      priceRange: priceRange,
      rating: rating,
      reviewCount: reviewCount,
      tags: tags,
      address: address,
      phone: phone,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Restaurant.fromFirestore(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: (data['name'] ?? '') as String,
      category: (data['category'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      imageURL: (data['imageURL'] ?? '') as String,
      isOpen: (data['isOpen'] ?? false) as bool,
      latitude: (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : 0.0,
      longitude: (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : 0.0,
      openingHours: (data['openingHours'] ?? '') as String,
      priceRange: (data['priceRange'] ?? '') as String,
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0,
      reviewCount: (data['reviewCount'] is num) ? (data['reviewCount'] as num).toInt() : 0,
      tags: (data['tags'] != null)
        ? List<String>.from(data['tags'])
        : [],
      address: (data['address'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
    );
  }
}