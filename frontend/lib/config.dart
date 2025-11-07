import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const String _ENV_BASE_URL = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

String get BASE_URL {
  if (_ENV_BASE_URL.isNotEmpty) return _ENV_BASE_URL;
  if (kIsWeb) return 'http://localhost:5001';
  if (Platform.isAndroid) return 'http://10.0.2.2:5001'; // Android emulator loopback
  return 'http://localhost:5001'; // iOS simulator/macOS default
}

// Optional dev overrides for simulator/mac location
const String _DEV_LAT_STR = String.fromEnvironment('DEV_LAT', defaultValue: '');
const String _DEV_LNG_STR = String.fromEnvironment('DEV_LNG', defaultValue: '');

double get DEV_LAT => double.tryParse(_DEV_LAT_STR.isEmpty ? 'NaN' : _DEV_LAT_STR) ?? 22.5726;
double get DEV_LNG => double.tryParse(_DEV_LNG_STR.isEmpty ? 'NaN' : _DEV_LNG_STR) ?? 88.3639;
