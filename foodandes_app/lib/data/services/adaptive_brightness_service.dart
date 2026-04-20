import 'dart:async';

import 'package:ambient_light/ambient_light.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

class AdaptiveBrightnessService {
  AdaptiveBrightnessService._();

  static final AdaptiveBrightnessService instance =
      AdaptiveBrightnessService._();

  final AmbientLight _ambientLight = AmbientLight();

  StreamSubscription<double>? _ambientLightSubscription;
  DateTime? _lastAppliedAt;
  double? _lastBrightness;
  bool _isRunning = false;

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    if (_isRunning || !_isSupportedPlatform) return;

    _isRunning = true;

    try {
      await ScreenBrightness.instance.setAutoReset(true);

      final initialLux = await _ambientLight.currentAmbientLight();
      if (initialLux != null) {
        await _applyBrightnessForLux(initialLux);
      }

      _ambientLightSubscription = _ambientLight.ambientLightStream.listen(
        (lux) async {
          await _applyBrightnessForLux(lux);
        },
        onError: (_) {
          // Ignore devices without a light sensor or transient stream errors.
        },
      );
    } catch (_) {
      _isRunning = false;
    }
  }

  Future<void> stop() async {
    await _ambientLightSubscription?.cancel();
    _ambientLightSubscription = null;
    _lastAppliedAt = null;
    _lastBrightness = null;
    _isRunning = false;

    if (!_isSupportedPlatform) return;

    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      // Ignore reset failures.
    }
  }

  Future<void> _applyBrightnessForLux(double lux) async {
    final now = DateTime.now();

    if (_lastAppliedAt != null &&
        now.difference(_lastAppliedAt!) < const Duration(milliseconds: 700)) {
      return;
    }

    final brightness = _mapLuxToBrightness(lux);

    if (_lastBrightness != null && (brightness - _lastBrightness!).abs() < 0.05) {
      return;
    }

    try {
      await ScreenBrightness.instance
          .setApplicationScreenBrightness(brightness);
      _lastBrightness = brightness;
      _lastAppliedAt = now;
    } catch (_) {
      // Ignore unsupported-device errors.
    }
  }

  double _mapLuxToBrightness(double lux) {
    if (lux < 5) return 0.18;
    if (lux < 20) return 0.25;
    if (lux < 80) return 0.38;
    if (lux < 250) return 0.52;
    if (lux < 1000) return 0.72;
    return 0.9;
  }
}
