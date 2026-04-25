import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:foodandes_app/app/app.dart';
import 'package:foodandes_app/data/services/analytics_service.dart';
import 'package:foodandes_app/firebase_options.dart';
import 'package:foodandes_app/data/services/offline_sync_worker.dart';

// FIX #3/#4 (lentitud al arranque):
// La version anterior creaba una instancia suelta de AuthServices en main() y
// abria un listener que nunca se cancelaba → memory leak + llamada extra a
// Firestore en cada cambio de estado de auth.
// El sync del documento de usuario ahora lo maneja auth_services.dart
// directamente con await, sin necesitar un listener global aqui.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  OfflineSyncWorker.instance.start();

  await AnalyticsService.instance.initialize();

  runApp(const FoodAndesApp());
}
