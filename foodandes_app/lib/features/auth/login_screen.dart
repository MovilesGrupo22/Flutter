import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';
import 'package:foodandes_app/core/constants/app_strings.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/auth_services.dart';
import 'package:foodandes_app/features/auth/register_screen.dart';
import 'package:foodandes_app/features/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthServices _authServices = AuthServices();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Email / Password Login ───────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter your email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential =
          await _authServices.login(email: email, password: password);

      final user = credential.user;
      if (user != null) {
        await AnalyticsService.instance.setUser(
          userId: user.uid,
          email: user.email,
        );
        await AnalyticsService.instance.logSignIn(
          method: 'email',
          userId: user.uid,
        );
        await AnalyticsService.instance.logUserSessionStart(
          userId: user.uid,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      debugPrint('LOGIN ERROR -> code: ${e.code}, message: ${e.message}');
      _showSnack(
        e.message != null
            ? 'Login failed [${e.code}]: ${e.message}'
            : 'Login failed [${e.code}]',
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Unexpected error during login');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Google Login ─────────────────────────────────────────────────────────

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _authServices.signInWithGoogle();

      if (credential == null) {
        // User cancelled the Google picker — do nothing
        return;
      }

      final user = credential.user;
      if (user != null) {
        await AnalyticsService.instance.setUser(
          userId: user.uid,
          email: user.email,
        );
        await AnalyticsService.instance.logSignIn(
          method: 'google',
          userId: user.uid,
        );
        await AnalyticsService.instance.logUserSessionStart(
          userId: user.uid,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack('Google login failed: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not sign in with Google. Please try again.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ─── Forgot Password ──────────────────────────────────────────────────────

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showSnack('Enter your email above first, then tap Forgot password.');
      return;
    }

    try {
      await _authServices.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showSnack(
        'Reset email sent to $email. Check your inbox.',
        duration: const Duration(seconds: 4),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack('Could not send reset email: ${e.message ?? e.code}');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 40, 24, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    const Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppStrings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Email ────────────────────────────────────────────────
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Email'),
                    ),
                    const SizedBox(height: 16),

                    // ── Password ─────────────────────────────────────────────
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isLoading ? null : _handleLogin(),
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

                    // ── Forgot password ──────────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Login button ─────────────────────────────────────────
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
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
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── Divider ───────────────────────────────────────────────
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Google button ─────────────────────────────────────────
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _isGoogleLoading ? null : _handleGoogleLogin,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              height: 22,
                              width: 22,
                            ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Register link ─────────────────────────────────────────
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                            context, RegisterScreen.routeName);
                      },
                      child: const Text(
                        "Don't have an account? Register",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
