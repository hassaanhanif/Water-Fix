import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String appName = 'WaterFix';
  static const String projectId = 'waterfix-mobile';
  static const String applicationId = 'com.waterfix.app';
  static const double defaultCommissionRate = 0.10;

  // Laptop Wi-Fi IPv4 address so physical phones (even after unplugging USB)
  // and emulators on the same laptop can both reach the local Express backend:
  static const String laptopLanIp = '192.168.18.131';

  static const String _customUrlPrefKey = 'waterfix_custom_api_base_url';
  static String? _overrideBaseUrl;

  /// Compile-time override if passed via:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.18.131:5000/api
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Configurable OpenStreetMap-compatible raster tile URL template.
  /// Can be overridden for production commercial scale via:
  /// --dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=YOUR_KEY
  static const String _envMapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: '',
  );

  static String get mapTileUrl {
    if (_envMapTileUrl.isNotEmpty) {
      return _envMapTileUrl;
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static const String osrmRoutingBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_customUrlPrefKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _overrideBaseUrl = saved.trim();
      }
    } catch (_) {}
  }

  static Future<void> setCustomBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      _overrideBaseUrl = null;
      await prefs.remove(_customUrlPrefKey);
    } else {
      String cleaned = url.trim();
      if (cleaned.endsWith('/')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      if (!cleaned.endsWith('/api')) {
        cleaned = '$cleaned/api';
      }
      _overrideBaseUrl = cleaned;
      await prefs.setString(_customUrlPrefKey, cleaned);
    }
  }

  static String get apiBaseUrl {
    if (_overrideBaseUrl != null && _overrideBaseUrl!.isNotEmpty) {
      return _overrideBaseUrl!;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://$laptopLanIp:5000/api';
    }
    return 'http://127.0.0.1:5000/api';
  }
}
