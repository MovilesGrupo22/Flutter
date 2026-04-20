import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Email / Password ──────────────────────────────────────────────────────

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _ensureUserDocument(
      user: credential.user,
      fallbackName: name,
      isNewUser: true,
    );

    return credential;
  }

  /// Sends a Firebase password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  /// Launches the Google sign-in flow and persists the user document.
  /// Returns `null` if the user cancels the flow.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user dismissed the picker

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    await _ensureUserDocument(
      user: userCredential.user,
      fallbackName: googleUser.displayName,
      isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
    );

    return userCredential;
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Sign out from Google too so the picker shows next time
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<void> _ensureUserDocument({
    required User? user,
    String? fallbackName,
    bool isNewUser = false,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final existingData = snapshot.data() ?? <String, dynamic>{};

    final resolvedName =
        (fallbackName ?? user.displayName ?? existingData['name'] ?? '')
            .toString()
            .trim();

    final safeName = resolvedName.isNotEmpty
        ? resolvedName
        : (user.email?.split('@').first ?? 'User');

    await userRef.set({
      'name': safeName,
      'email': user.email ?? existingData['email'] ?? '',
      'favoriteRestaurants':
          List<String>.from(existingData['favoriteRestaurants'] ?? const []),
      'dietaryPreferences':
          List<String>.from(existingData['dietaryPreferences'] ?? const []),
      if (!snapshot.exists)
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      'authProvider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
      if (isNewUser) 'registeredWithEmail': true,
    }, SetOptions(merge: true));
  }
}
