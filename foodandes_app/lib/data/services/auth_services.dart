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

  // ─── Email / Password ──────────────────────────────────────────────────────

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // FIX #4: era unawaited → silenciosamente fallaba y dejaba el doc desactualizado.
    // Para login el doc ya existe, pero actualizamos lastLoginAt de forma confiable.
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

    // FIX: await obligatorio — el doc DEBE existir antes de ir a HomeScreen
    // porque Firestore Rules y UserService dependen de él.
    await _ensureUserDocument(
      user: credential.user,
      fallbackName: name,
      isNewUser: true,
    );

    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // usuario canceló

    final googleAuth = await googleUser.authentication;

    final oauthCredential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    // FIX #1: era unawaited → el documento nunca se creaba (o se creaba después
    // de que HomeScreen ya intentaba leerlo). Ahora se espera explícitamente
    // antes de retornar, garantizando que el doc existe cuando se navega.
    await _ensureUserDocument(
      user: userCredential.user,
      fallbackName: googleUser.displayName,
      isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
    );

    return userCredential;
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    // Cerrar sesión de Google también para que el picker vuelva a aparecer.
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ─── Sync (llamado por pantallas que necesitan doc actualizado) ────────────

  Future<void> syncCurrentUserDocument() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _ensureUserDocument(
      user: user,
      fallbackName: user.displayName,
      isNewUser: false,
    );
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<void> _ensureUserDocument({
    required User? user,
    String? fallbackName,
    required bool isNewUser,
  }) async {
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    final resolvedName =
        (fallbackName ?? user.displayName ?? '').toString().trim();
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

    // Campos que solo se escriben la primera vez
    if (isNewUser) {
      payload.addAll({
        'favoriteRestaurants': <String>[],
        'dietaryPreferences': <String>[],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      // Para usuarios existentes nos aseguramos de que favoriteRestaurants
      // siempre esté presente (puede faltar en cuentas muy antiguas).
      final snap = await userRef.get();
      if (snap.exists && snap.data()?['favoriteRestaurants'] == null) {
        payload['favoriteRestaurants'] = <String>[];
      }
    }

    try {
      await userRef
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
      debugPrint('USER DOC SYNC OK -> ${user.uid}');
    } catch (e) {
      debugPrint('USER DOC SYNC ERROR -> $e');
      // No relanzamos: el login igual continúa; Firestore offline cache
      // garantizará los datos en el próximo sync.
    }
  }
}
