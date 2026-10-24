import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for sensitive data (tokens, credentials)
class SecureStorage {
  SecureStorage._();

  static final SecureStorage _instance = SecureStorage._();
  static SecureStorage get instance => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // ============ GENERIC METHODS ============

  /// Save a value securely
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value securely
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete all values
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Get all keys
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }

  // ============ TOKEN METHODS ============

  static const String _tokenKey = 'auth_token';

  /// Save auth token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Get auth token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Delete auth token
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}