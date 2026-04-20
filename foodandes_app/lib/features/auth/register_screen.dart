import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/auth_services.dart';
import 'package:foodandes_app/features/home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const String routeName = '/register';

  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthServices _authServices = AuthServices();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ─── Email Registration ────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authServices.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );

      if (user != null) {
        unawaited(_logSignUpAnalytics(user, 'email'));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('REGISTER ERROR -> code: ${e.code}, message: ${e.message}');
      _showSnack(
        e.message != null
            ? 'Register failed [${e.code}]: ${e.message}'
            : 'Register failed [${e.code}]',
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unexpected error during register');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Registration ───────────────────────────────────────────────────

  Future<void> _handleGoogleRegister() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _authServices.signInWithGoogle();

      if (credential == null) return; // User cancelled

      final user = credential.user;
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeScreen.routeName,
        (route) => false,
      );

      if (user != null) {
        unawaited(
          isNewUser
              ? _logSignUpAnalytics(user, 'google')
              : _logSignInAnalytics(user, 'google'),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack('Google sign-up failed: ${e.message ?? e.code}');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not sign up with Google. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }


  Future<void> _logSignUpAnalytics(User user, String method) async {
    try {
      await AnalyticsService.instance.setUser(
        userId: user.uid,
        email: user.email,
      );
      await AnalyticsService.instance.logSignUp(
        method: method,
        userId: user.uid,
      );
      await AnalyticsService.instance.logUserSessionStart(
        userId: user.uid,
      );
    } catch (e) {
      debugPrint('SIGN UP ANALYTICS ERROR -> $e');
    }
  }


  Future<void> _logSignInAnalytics(User user, String method) async {
    try {
      await AnalyticsService.instance.setUser(
        userId: user.uid,
        email: user.email,
      );
      await AnalyticsService.instance.logSignIn(
        method: method,
        userId: user.uid,
      );
      await AnalyticsService.instance.logUserSessionStart(
        userId: user.uid,
      );
    } catch (e) {
      debugPrint('SIGN IN ANALYTICS ERROR -> $e');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Google button (top for fast sign-up) ──────────────────
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed:
                        _isGoogleLoading ? null : _handleGoogleRegister,
                    icon: _isGoogleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.account_circle_outlined,
                            color: AppColors.textPrimary,
                          ),
                    label: const Text(
                      'Sign up with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Divider ───────────────────────────────────────────────
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or register with email',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Email form ────────────────────────────────────────────
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(hintText: 'Full name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration:
                        const InputDecoration(hintText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _isLoading ? null : _handleRegister(),
                    decoration: InputDecoration(
                      hintText: 'Confirm password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
