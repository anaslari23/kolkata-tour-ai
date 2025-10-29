import 'package:flutter/material.dart';

class Place {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> images;
  final List<String> tags;
  final double lat;
  final double lng;
  final double? distanceKm;
  final String? city;
  final String? type;
  final String? story;
  final String? image; // primary image url from backend
  final String? history;
  final String? personalTips;
  final String? pastEvents;
  final String? openingInfo;
  final List<String>? nearbyRecommendations;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.images,
    required this.tags,
    required this.lat,
    required this.lng,
    this.distanceKm,
    this.city,
    this.type,
    this.story,
    this.image,
    this.history,
    this.personalTips,
    this.pastEvents,
    this.openingInfo,
    this.nearbyRecommendations,
  });

  factory Place.fromJson(Map<String, dynamic> j) {
    return Place(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      images: (j['images'] as List?)?.map((e) => e.toString()).toList() ?? (j['image'] != null ? [j['image'].toString()] : <String>[]),
      tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      lat: (() {
        final v = j['lat'] ?? j['Latitude'] ?? j['latitude'];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '0') ?? 0;
      })(),
      lng: (() {
        final v = j['lng'] ?? j['Longitude'] ?? j['longitude'] ?? j['lon'] ?? j['long'];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '0') ?? 0;
      })(),
      distanceKm: (j['distance_km'] is num) ? (j['distance_km'] as num).toDouble() : double.tryParse(j['distance_km']?.toString() ?? ''),
      city: j['city']?.toString(),
      type: j['type']?.toString(),
      story: j['story']?.toString(),
      image: j['image']?.toString(),
      history: j['History']?.toString() ?? j['history']?.toString(),
      personalTips: j['Personal Tips']?.toString() ?? j['personal_tips']?.toString(),
      pastEvents: j['Past Events']?.toString() ?? j['past_events']?.toString(),
      openingInfo: j['Opening Hours, Price, Best Time']?.toString() ?? j['opening_info']?.toString(),
      nearbyRecommendations: (){
        final v = j['Nearby Recommendations'];
        if (v is List) return v.map((e)=>e.toString()).toList();
        if (v is String) {
          return v.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
        }
        return null;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'images': images,
        'tags': tags,
        'lat': lat,
        'lng': lng,
        'distance_km': distanceKm,
        'city': city,
        'type': type,
        'story': story,
        'image': image,
        'history': history,
        'personal_tips': personalTips,
        'past_events': pastEvents,
        'opening_info': openingInfo,
        'nearby_recommendations': nearbyRecommendations,
      };
}

class Message {
  final bool isUser;
  final String text;
  final String? imageUrl;
  final List<Place>? suggestions;

  const Message({required this.isUser, required this.text, this.imageUrl, this.suggestions});
}
