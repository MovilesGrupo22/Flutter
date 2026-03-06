class Restaurant {
  final String id;
  final String name;
  final String category;
  final double rating;
  final int priceLevel;
  final bool isOpen;
  final bool isFavorite;
  final String imageUrl;
  final String description;
  final List<String> menuItems;

  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.priceLevel,
    required this.isOpen,
    required this.isFavorite,
    required this.imageUrl,
    required this.description,
    required this.menuItems,
  });

  Restaurant copyWith({
    bool? isFavorite,
  }) {
    return Restaurant(
      id: id,
      name: name,
      category: category,
      rating: rating,
      priceLevel: priceLevel,
      isOpen: isOpen,
      isFavorite: isFavorite ?? this.isFavorite,
      imageUrl: imageUrl,
      description: description,
      menuItems: menuItems,
    );
  }
}