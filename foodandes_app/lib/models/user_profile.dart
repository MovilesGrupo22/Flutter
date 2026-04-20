class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String photoURL;
  final List<String> favoriteRestaurants;
  final List<String> dietaryPreferences;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    required this.favoriteRestaurants,
    required this.dietaryPreferences,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'] ?? data['photoUrl'] ?? '',
      favoriteRestaurants: List<String>.from(data['favoriteRestaurants'] ?? []),
      dietaryPreferences: List<String>.from(data['dietaryPreferences'] ?? []),
    );
  }
}
