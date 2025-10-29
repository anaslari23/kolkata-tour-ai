import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place.dart';

class AppPrefs {
  String mood;
  List<String> interests;
  String timePreference;
  String transportMode; // walk/scooter/car/metro
  String pace; // quick/normal/slow
  int availableTimeMin;
  double walkingDistanceKm;
  String companion; // solo/couple/family/friends
  bool vegOnly;
  bool streetFoodOk;

  AppPrefs({
    this.mood = 'calm',
    List<String>? interests,
    this.timePreference = 'evening',
    this.transportMode = 'car',
    this.pace = 'normal',
    this.availableTimeMin = 40,
    this.walkingDistanceKm = 1.2,
    this.companion = 'solo',
    this.vegOnly = false,
    this.streetFoodOk = true,
  }) : interests = interests ?? <String>['quiet places', 'heritage', 'tea stalls'];

  Map<String, dynamic> toRoutePayload() => {
        'transport_mode': transportMode,
        'pace': pace,
        'available_time_min': availableTimeMin,
        'tolerance': {'walking_distance_km': walkingDistanceKm},
        'intent': _inferIntent(),
      };

  Map<String, dynamic> toPrefsPayload() => {
        'mood': mood,
        'interests': interests,
        'time_preference': timePreference,
        'companion': companion,
        'dietary': {
          'veg_only': vegOnly,
          'street_food_ok': streetFoodOk,
        }
      };

  String _inferIntent() {
    final s = interests.join(' ').toLowerCase();
    if (s.contains('food') || s.contains('tea') || s.contains('cafe')) return 'food';
    if (s.contains('photo') || s.contains('iconic')) return 'photography';
    if (s.contains('history') || s.contains('heritage') || s.contains('museum')) return 'history';
    if (s.contains('quiet') || s.contains('calm')) return 'quiet';
    return 'explore';
  }
}

final ValueNotifier<AppPrefs> prefsNotifier = ValueNotifier<AppPrefs>(AppPrefs());

Future<void> loadPrefs() async {
  final sp = await SharedPreferences.getInstance();
  final p = AppPrefs(
    mood: sp.getString('mood') ?? 'calm',
    interests: sp.getStringList('interests') ?? ['quiet places', 'heritage', 'tea stalls'],
    timePreference: sp.getString('timePreference') ?? 'evening',
    transportMode: sp.getString('transportMode') ?? 'car',
    pace: sp.getString('pace') ?? 'normal',
    availableTimeMin: sp.getInt('availableTimeMin') ?? 40,
    walkingDistanceKm: sp.getDouble('walkingDistanceKm') ?? 1.2,
    companion: sp.getString('companion') ?? 'solo',
    vegOnly: sp.getBool('vegOnly') ?? false,
    streetFoodOk: sp.getBool('streetFoodOk') ?? true,
  );
  prefsNotifier.value = p;
  await FavoritesStore.instance.load();
}

Future<void> savePrefs(AppPrefs p) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString('mood', p.mood);
  await sp.setStringList('interests', p.interests);
  await sp.setString('timePreference', p.timePreference);
  await sp.setString('transportMode', p.transportMode);
  await sp.setString('pace', p.pace);
  await sp.setInt('availableTimeMin', p.availableTimeMin);
  await sp.setDouble('walkingDistanceKm', p.walkingDistanceKm);
  await sp.setString('companion', p.companion);
  await sp.setBool('vegOnly', p.vegOnly);
  await sp.setBool('streetFoodOk', p.streetFoodOk);
}

class FavoritesStore {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  final ValueNotifier<List<Place>> favorites = ValueNotifier<List<Place>>(<Place>[]);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList('favorites') ?? <String>[];
    final List<Place> items = [];
    for (final s in raw) {
      try {
        final Map<String, dynamic> j = jsonDecode(s) as Map<String, dynamic>;
        items.add(Place.fromJson(j));
      } catch (_) {}
    }
    favorites.value = items;
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    final list = favorites.value.map((p) => jsonEncode(p.toJson())).toList();
    await sp.setStringList('favorites', list);
  }

  bool isFavorite(Place p) => favorites.value.any((x) => x.id == p.id);

  Future<void> toggle(Place p) async {
    final list = List<Place>.from(favorites.value);
    final idx = list.indexWhere((x) => x.id == p.id);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(p);
    }
    favorites.value = list;
    await _persist();
  }
}