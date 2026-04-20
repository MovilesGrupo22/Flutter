import 'package:flutter/material.dart';
import 'package:foodandes_app/app/routes.dart';
import 'package:foodandes_app/app/theme.dart';
import 'package:foodandes_app/data/services/adaptive_brightness_service.dart';
import 'package:foodandes_app/features/auth/auth_gate.dart';

// FIX #5 (sesion no persiste): la version anterior uso StatelessWidget con
// initialRoute '/login', ignorando la sesion persistida por Firebase.
// FIX #6 (brillo roto): al convertirlo en Stateless se perdio el
// WidgetsBindingObserver que controlaba AdaptiveBrightnessService.

class FoodAndesApp extends StatefulWidget {
  const FoodAndesApp({super.key});

  @override
  State<FoodAndesApp> createState() => _FoodAndesAppState();
}

class _FoodAndesAppState extends State<FoodAndesApp>
    with WidgetsBindingObserver {
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
      // AuthGate escucha el stream de Firebase: si hay sesion activa va directo
      // a HomeScreen sin pasar por LoginScreen.
      home: const AuthGate(),
    );
  }
}
