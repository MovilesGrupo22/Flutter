class UserProfile {
  final String name;
  final String email;
  final int favoritesCount;
  final int reviewsCount;

  const UserProfile({
    required this.name,
    required this.email,
    required this.favoritesCount,
    required this.reviewsCount,
  });
}