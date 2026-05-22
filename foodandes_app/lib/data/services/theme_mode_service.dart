import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  light,
  dark,
  adaptive,
}

extension AppThemePreferenceLabel on AppThemePreference {
  String get storageValue => name;

  String get label {
    switch (this) {
      case AppThemePreference.light:
        return 'Light mode';
      case AppThemePreference.dark:
        return 'Dark mode';
      case AppThemePreference.adaptive:
        return 'Auto by ambient light';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreference.light:
        return 'Always use the light interface.';
      case AppThemePreference.dark:
        return 'Always use the dark interface.';
      case AppThemePreference.adaptive:
        return 'Switch to dark mode when the light sensor detects low light.';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemePreference.light:
        return Icons.light_mode_outlined;
      case AppThemePreference.dark:
        return Icons.dark_mode_outlined;
      case AppThemePreference.adaptive:
        return Icons.brightness_auto_outlined;
    }
  }

  static AppThemePreference fromStorageValue(String? value) {
    for (final preference in AppThemePreference.values) {
      if (preference.storageValue == value) return preference;
    }
    return AppThemePreference.adaptive;
  }
}

class ThemeModeService extends ChangeNotifier {
  ThemeModeService._();

  static final ThemeModeService instance = ThemeModeService._();

  static const String _themePreferenceKey = 'theme_preference';

  // The hysteresis window prevents flickering when the sensor is close to the
  // threshold. Below 25 lux the app becomes dark, above 80 lux it returns to
  // light mode when the user selected the adaptive option.
  static const double lowLightThresholdLux = 25.0;
  static const double brightLightThresholdLux = 80.0;

  AppThemePreference _preference = AppThemePreference.adaptive;
  bool _isLowLight = false;
  bool _isLoaded = false;
  double? _lastLux;
  Future<void>? _loadFuture;

  AppThemePreference get preference => _preference;
  bool get isLoaded => _isLoaded;
  bool get isLowLight => _isLowLight;
  double? get lastLux => _lastLux;

  bool get isAdaptiveEnabled => _preference == AppThemePreference.adaptive;

  ThemeMode get effectiveThemeMode {
    switch (_preference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.adaptive:
        return _isLowLight ? ThemeMode.dark : ThemeMode.light;
    }
  }

  String get effectiveLabel {
    switch (effectiveThemeMode) {
      case ThemeMode.light:
        return 'Light mode active';
      case ThemeMode.dark:
        return 'Dark mode active';
      case ThemeMode.system:
        return 'System mode active';
    }
  }

  Future<void> load() {
    _loadFuture ??= _loadFromDisk();
    return _loadFuture!;
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _preference = AppThemePreferenceLabel.fromStorageValue(
      prefs.getString(_themePreferenceKey),
    );
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    _preference = preference;
    _isLoaded = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, preference.storageValue);
  }

  void updateAmbientLux(double lux) {
    final previousLux = _lastLux;
    final wasLowLight = _isLowLight;

    _lastLux = lux;

    if (lux < lowLightThresholdLux) {
      _isLowLight = true;
    } else if (lux > brightLightThresholdLux) {
      _isLowLight = false;
    }

    final luxChangedEnough = previousLux == null || (lux - previousLux).abs() >= 5;
    final lowLightChanged = wasLowLight != _isLowLight;

    if (luxChangedEnough || lowLightChanged) {
      notifyListeners();
    }
  }
}
