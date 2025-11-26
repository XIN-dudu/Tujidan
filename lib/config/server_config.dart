import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  static const String _storageKey = 'server_ip';
  static const String _defaultHost = '127.0.0.1';
  static const String _port = '3001';
  static String? _cachedHost;

  static Future<String> getHost() async {
    if (_cachedHost != null) return _cachedHost!;
    final prefs = await SharedPreferences.getInstance();
    _cachedHost = prefs.getString(_storageKey) ?? _defaultHost;
    return _cachedHost!;
  }

  static Future<void> setHost(String host) async {
    _cachedHost = host.isEmpty ? _defaultHost : host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _cachedHost!);
  }

  static Future<String> getBaseUrl() async {
    final host = await getHost();
    return 'http://$host:$_port/api';
  }

  static Future<String> getFileBaseUrl() async {
    final host = await getHost();
    return 'http://$host:$_port';
  }
}

