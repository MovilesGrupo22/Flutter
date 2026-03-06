import 'package:flutter/material.dart';
import 'package:foodandes_app/app/routes.dart';
import 'package:foodandes_app/app/theme.dart';
import 'package:foodandes_app/features/auth/login_screen.dart';

class FoodAndesApp extends StatelessWidget {
  const FoodAndesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurandes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      initialRoute: LoginScreen.routeName,
    );
  }
}