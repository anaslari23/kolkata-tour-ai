import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/place.dart';

class ApiService {
  final String baseUrl;
  const ApiService({this.baseUrl = BASE_URL});

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('POST $path failed: ${res.statusCode} ${res.body}');
  }

  Future<List<Place>> search({required String query, String? city = 'Kolkata', String? type, int k = 20}) async {
    final uri = Uri.parse('$baseUrl/search');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'query': query,
      'city': city,
      'type': type,
      'k': k,
    }));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['results'] as List? ?? []);
      return list.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Search failed: ${res.statusCode} ${res.body}');
  }

  Future<Message> chat(String message, {String? city = 'Kolkata', String userId = 'A123', int? hour}) async {
    final uri = Uri.parse('$baseUrl/chat');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'message': message,
      'city': city,
      'user_id': userId,
      'hour': hour ?? DateTime.now().hour,
    }));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ctx = (data['context'] as List? ?? []);
      String? img;
      List<Place> sug = [];
      if (ctx.isNotEmpty) {
        final first = ctx.first as Map<String, dynamic>;
        img = (first['image'] ?? (first['images'] is List && (first['images'] as List).isNotEmpty ? (first['images'] as List).first : null))?.toString();
        sug = ctx.map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map))).take(4).toList();
      }
      return Message(isUser: false, text: data['answer']?.toString() ?? '', imageUrl: img, suggestions: sug);
    }
    throw Exception('Chat failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> routeSuggestions({
    required String userId,
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    int? hour,
    String? weather,
    double? tempC,
    double thresholdKm = 1.2,
    int k = 5,
    // extended params
    String transportMode = 'car',
    String pace = 'normal',
    int availableTimeMin = 40,
    double walkingDistanceKm = 1.2,
    String? intent,
  }) async {
    final uri = Uri.parse('$baseUrl/route_suggestions');
    final body = jsonEncode({
      'user_id': userId,
      'user_lat': userLat,
      'user_lng': userLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'hour': hour ?? DateTime.now().hour,
      'weather': weather,
      'temp_c': tempC,
      'threshold_km': thresholdKm,
      'k': k,
      'transport_mode': transportMode,
      'pace': pace,
      'available_time_min': availableTimeMin,
      'tolerance': {'walking_distance_km': walkingDistanceKm},
      if (intent != null) 'intent': intent,
    });
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('route_suggestions failed: ${res.statusCode} ${res.body}');
  }

  Future<List<Place>> getPlaces({String? city = 'Kolkata', String? type}) async {
    final q = {
      if (city != null) 'city': city,
      if (type != null) 'type': type,
    };
    final uri = Uri.parse('$baseUrl/places').replace(queryParameters: q);
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['results'] as List? ?? []);
      return list.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('getPlaces failed: ${res.statusCode} ${res.body}');
  }
}
