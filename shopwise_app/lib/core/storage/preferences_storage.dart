import 'package:shared_preferences/shared_preferences.dart';

/// Preferences storage for non-sensitive data
class PreferencesStorage {
  PreferencesStorage._();
  
  static final PreferencesStorage _instance = PreferencesStorage._();
  static PreferencesStorage get instance => _instance;
  
  SharedPreferences? _prefs;
  
  /// Initialize shared preferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('PreferencesStorage not initialized. Call init() first.');
    }
    return _prefs!;
  }
  
  // String methods
  Future<bool> setString(String key, String value) async {
    await init();
    return await prefs.setString(key, value);
  }
  
  String? getString(String key) {
    return prefs.getString(key);
  }
  
  // Int methods
  Future<bool> setInt(String key, int value) async {
    await init();
    return await prefs.setInt(key, value);
  }
  
  int? getInt(String key) {
    return prefs.getInt(key);
  }
  
  // Bool methods
  Future<bool> setBool(String key, bool value) async {
    await init();
    return await prefs.setBool(key, value);
  }
  
  bool? getBool(String key) {
    return prefs.getBool(key);
  }
  
  // Double methods
  Future<bool> setDouble(String key, double value) async {
    await init();
    return await prefs.setDouble(key, value);
  }
  
  double? getDouble(String key) {
    return prefs.getDouble(key);
  }
  
  // StringList methods
  Future<bool> setStringList(String key, List<String> value) async {
    await init();
    return await prefs.setStringList(key, value);
  }
  
  List<String>? getStringList(String key) {
    return prefs.getStringList(key);
  }
  
  // Remove
  Future<bool> remove(String key) async {
    await init();
    return await prefs.remove(key);
  }
  
  // Clear all
  Future<bool> clear() async {
    await init();
    return await prefs.clear();
  }
  
  // Contains key
  bool containsKey(String key) {
    return prefs.containsKey(key);
  }
  
  // Get all keys
  Set<String> getKeys() {
    return prefs.getKeys();
  }
}
