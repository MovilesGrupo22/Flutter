import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/app/app.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/data/services/auth_services.dart';
import 'package:foodandes_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AnalyticsService.instance.initialize();

  final authServices = AuthServices();
  authServices.authStateChanges.listen((user) {
    if (user != null) {
      unawaited(authServices.syncCurrentUserDocument());
    }
  });

  runApp(const FoodAndesApp());
}
