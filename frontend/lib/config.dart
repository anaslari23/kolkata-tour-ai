const String BASE_URL = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://localhost:5001');

// Optional dev overrides for simulator/mac location
const String _DEV_LAT_STR = String.fromEnvironment('DEV_LAT', defaultValue: '');
const String _DEV_LNG_STR = String.fromEnvironment('DEV_LNG', defaultValue: '');

double get DEV_LAT => double.tryParse(_DEV_LAT_STR.isEmpty ? 'NaN' : _DEV_LAT_STR) ?? 22.5726;
double get DEV_LNG => double.tryParse(_DEV_LNG_STR.isEmpty ? 'NaN' : _DEV_LNG_STR) ?? 88.3639;
