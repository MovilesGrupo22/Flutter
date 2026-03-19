class UserProfile {
  final String uid;
  final String name;
  final String email;
  final List<String> favoriteRestaurants;
  final List<String> dietaryPreferences;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.favoriteRestaurants,
    required this.dietaryPreferences,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      favoriteRestaurants: List<String>.from(data['favoriteRestaurants'] ?? []),
      dietaryPreferences: List<String>.from(data['dietaryPreferences'] ?? []),
    );
  }
}