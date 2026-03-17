/// Server URL configuration with persistent storage.
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _key = 'server_url';
  static String _serverUrl = 'http://localhost:11408';

  static String get serverUrl => _serverUrl;
  static String get apiBase => '$_serverUrl/api/v1';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_key) ?? _serverUrl;
  }

  static Future<void> setServerUrl(String url) async {
    // Remove trailing slash
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _serverUrl);
  }
}
