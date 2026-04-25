import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();
  factory PreferencesService() => instance;

  static const _keyCategory = 'selected_category';
  static const _keyOnlyOpen = 'only_open';
  static const _keyOnlyTopRated = 'only_top_rated';
  static const _keyPriceRange = 'selected_price_range';

  Future<void> saveSelectedCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategory, category);
  }

  Future<String> getSelectedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCategory) ?? 'All';
  }

  Future<void> saveOnlyOpen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnlyOpen, value);
  }

  Future<bool> getOnlyOpen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnlyOpen) ?? false;
  }

  Future<void> saveOnlyTopRated(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnlyTopRated, value);
  }

  Future<bool> getOnlyTopRated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnlyTopRated) ?? false;
  }

  Future<void> saveSelectedPriceRange(String range) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPriceRange, range);
  }

  Future<String> getSelectedPriceRange() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPriceRange) ?? 'All';
  }
}
