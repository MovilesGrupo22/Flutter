import 'package:flutter/material.dart';
import 'package:foodandes_app/app/routes.dart';
import 'package:foodandes_app/app/theme.dart';
import 'package:foodandes_app/data/services/adaptive_brightness_service.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/features/auth/auth_gate.dart';

class FoodAndesApp extends StatefulWidget {
  const FoodAndesApp({super.key});

  @override
  State<FoodAndesApp> createState() => _FoodAndesAppState();
}

class _FoodAndesAppState extends State<FoodAndesApp>
    with WidgetsBindingObserver {
  final AppNavigationObserver _navigationObserver = AppNavigationObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdaptiveBrightnessService.instance.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdaptiveBrightnessService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        AdaptiveBrightnessService.instance.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        AdaptiveBrightnessService.instance.stop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurandes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      navigatorObservers: [_navigationObserver],
      home: const AuthGate(),
    );
  }
}
