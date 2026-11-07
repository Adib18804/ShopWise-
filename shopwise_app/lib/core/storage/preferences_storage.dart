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
    return prefs.setString(key, value);
  }
  
  String? getString(String key) => prefs.getString(key);
  
  // Int methods
  Future<bool> setInt(String key, int value) async {
    await init();
    return prefs.setInt(key, value);
  }
  
  int? getInt(String key) => prefs.getInt(key);
  
  // Bool methods
  Future<bool> setBool(String key, bool value) async {
    await init();
    return prefs.setBool(key, value);
  }
  
  bool? getBool(String key) => prefs.getBool(key);
  
  // Double methods
  Future<bool> setDouble(String key, double value) async {
    await init();
    return prefs.setDouble(key, value);
  }
  
  double? getDouble(String key) => prefs.getDouble(key);
  
  // StringList methods
  Future<bool> setStringList(String key, List<String> value) async {
    await init();
    return prefs.setStringList(key, value);
  }
  
  List<String>? getStringList(String key) => prefs.getStringList(key);
  
  // Remove
  Future<bool> remove(String key) async {
    await init();
    return prefs.remove(key);
  }
  
  // Clear all
  Future<bool> clear() async {
    await init();
    return prefs.clear();
  }
  
  // Contains key
  bool containsKey(String key) => prefs.containsKey(key);
  
  // Get all keys
  Set<String> getKeys() => prefs.getKeys();
}
