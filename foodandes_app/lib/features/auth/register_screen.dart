import 'package:flutter/material.dart';
import 'package:foodandes_app/core/constants/app_colors.dart';

class RegisterScreen extends StatelessWidget {
  static const String routeName = '/register';

  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(hintText: 'Full name')),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(hintText: 'Email')),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(hintText: 'Password'),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(hintText: 'Confirm password'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}