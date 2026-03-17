/// Server URL configuration with persistent storage.
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _key = 'server_url';
  static const _keySecret = 'server_key';
  static String _serverUrl = 'http://localhost:11408';
  static String _serverKey = '';

  static String get serverUrl => _serverUrl;
  static String get serverKey => _serverKey;
  static String get apiBase => '$_serverUrl/api/v1';
  static Map<String, String> get authHeaders =>
      _serverKey.isEmpty ? {} : {'X-CloudNote-Key': _serverKey};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_key) ?? _serverUrl;
    _serverKey = prefs.getString(_keySecret) ?? _serverKey;
  }

  static Future<void> setServerUrl(String url) async {
    // Remove trailing slash
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _serverUrl);
  }

  static Future<void> setServerKey(String key) async {
    _serverKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_serverKey.isEmpty) {
      await prefs.remove(_keySecret);
    } else {
      await prefs.setString(_keySecret, _serverKey);
    }
  }
}
