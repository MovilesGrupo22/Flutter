import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _ensureUserDocument(
      user: credential.user,
      fallbackName: credential.user?.displayName,
      isNewUser: false,
    );

    return credential;
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

    final safeName = name.trim();
    if (credential.user != null && safeName.isNotEmpty) {
      await credential.user!.updateDisplayName(safeName);
    }

    await _ensureUserDocument(
      user: credential.user,
      fallbackName: safeName,
      isNewUser: true,
    );

    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final oauthCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    await _ensureUserDocument(
      user: userCredential.user,
      fallbackName: googleUser.displayName,
      isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      additionalUserInfo: userCredential.additionalUserInfo,
      googleAccount: googleUser,
    );

    return userCredential;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> syncCurrentUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _ensureUserDocument(
      user: user,
      fallbackName: user.displayName,
      isNewUser: false,
    );
  }

  Future<void> _ensureUserDocument({
    required User? user,
    String? fallbackName,
    required bool isNewUser,
    AdditionalUserInfo? additionalUserInfo,
    GoogleSignInAccount? googleAccount,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    final profileData = additionalUserInfo?.profile;
    final resolvedName = _resolveDisplayName(
      user: user,
      fallbackName: fallbackName,
      googleAccount: googleAccount,
      profileData: profileData,
      normalizedEmail: normalizedEmail,
    );
    final resolvedPhotoUrl = _resolvePhotoUrl(
      user: user,
      googleAccount: googleAccount,
      profileData: profileData,
    );
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .where((providerId) => providerId.isNotEmpty)
        .toSet()
        .toList();
    final authProvider = _resolvePrimaryProvider(user);
    final nameParts = _extractNameParts(resolvedName);

    final payload = <String, dynamic>{
      'name': resolvedName,
      'firstName': nameParts['firstName'],
      'lastName': nameParts['lastName'],
      'email': normalizedEmail,
      'normalizedEmail': normalizedEmail,
      'photoURL': resolvedPhotoUrl,
      'emailVerified': user.emailVerified,
      'providerIds': providerIds,
      'authProvider': authProvider,
      'lastSignInProvider': authProvider,
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAtServer': FieldValue.serverTimestamp(),
    };

    try {
      if (isNewUser) {
        payload.addAll({
          'favoriteRestaurants': <String>[],
          'dietaryPreferences': <String>[],
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'createdAtServer': FieldValue.serverTimestamp(),
        });
      } else {
        final snap = await userRef.get().timeout(const Duration(seconds: 8));
        if (snap.exists && snap.data()?['favoriteRestaurants'] == null) {
          payload['favoriteRestaurants'] = <String>[];
        }
        if (snap.exists && snap.data()?['dietaryPreferences'] == null) {
          payload['dietaryPreferences'] = <String>[];
        }
      }

      await userRef
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      debugPrint('USER DOC SYNC OK -> ${user.uid}');
    } catch (e) {
      debugPrint('USER DOC SYNC ERROR -> $e');
    }
  }

  String _resolveDisplayName({
    required User user,
    String? fallbackName,
    GoogleSignInAccount? googleAccount,
    Map<String, dynamic>? profileData,
    required String normalizedEmail,
  }) {
    final rawName = (fallbackName ??
            user.displayName ??
            googleAccount?.displayName ??
            _asString(profileData?['name']) ??
            _asString(profileData?['given_name']) ??
            '')
        .trim();

    if (rawName.isNotEmpty) {
      return rawName;
    }

    if (normalizedEmail.isNotEmpty) {
      return normalizedEmail.split('@').first;
    }

    return 'User';
  }

  String _resolvePhotoUrl({
    required User user,
    GoogleSignInAccount? googleAccount,
    Map<String, dynamic>? profileData,
  }) {
    return (googleAccount?.photoUrl ??
            user.photoURL ??
            _asString(profileData?['picture']) ??
            '')
        .trim();
  }

  String _resolvePrimaryProvider(User user) {
    const knownProviders = ['google.com', 'password'];

    for (final provider in knownProviders) {
      final match = user.providerData.where(
        (item) => item.providerId == provider,
      );
      if (match.isNotEmpty) return provider;
    }

    for (final provider in user.providerData) {
      if (provider.providerId.isNotEmpty) {
        return provider.providerId;
      }
    }

    return 'password';
  }

  Map<String, String> _extractNameParts(String fullName) {
    final tokens = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return {
        'firstName': '',
        'lastName': '',
      };
    }

    if (tokens.length == 1) {
      return {
        'firstName': tokens.first,
        'lastName': '',
      };
    }

    return {
      'firstName': tokens.first,
      'lastName': tokens.sublist(1).join(' '),
    };
  }

  String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}
