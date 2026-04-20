import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

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

    unawaited(
      _ensureUserDocument(
        user: credential.user,
        fallbackName: credential.user?.displayName,
        isNewUser: false,
      ),
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

    unawaited(
      _ensureUserDocument(
        user: credential.user,
        fallbackName: name,
        isNewUser: true,
      ),
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

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    unawaited(
      _ensureUserDocument(
        user: userCredential.user,
        fallbackName: googleUser.displayName,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      ),
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
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    final resolvedName = (fallbackName ?? user.displayName ?? '').toString().trim();
    final safeName = resolvedName.isNotEmpty
        ? resolvedName
        : (user.email?.split('@').first ?? 'User');

    final payload = <String, dynamic>{
      'name': safeName,
      'email': user.email ?? '',
      'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
      'authProvider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
    };

    if (isNewUser) {
      payload.addAll({
        'favoriteRestaurants': <String>[],
        'dietaryPreferences': <String>[],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    try {
      await userRef.set(payload, SetOptions(merge: true)).timeout(
        const Duration(seconds: 6),
      );
      debugPrint('USER DOC SYNC OK -> ${user.uid}');
    } catch (e) {
      debugPrint('USER DOC SYNC ERROR -> $e');
    }
  }
}
