import 'package:flutter/material.dart';
import '../models/place.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api.dart';
import '../state/prefs.dart';
import '../state/prefs.dart' show FavoritesStore;
import '../widgets/widgets.dart';

class PlaceDetailsScreen extends StatelessWidget {
  final Place place;
  const PlaceDetailsScreen({super.key, required this.place});

  String _distanceLabel(double lat, double lng) {
    // This is a placeholder. In a real app, you'd calculate the distance.
    return '... km away';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> imgs = place.images.isNotEmpty
        ? place.images
        : (place.image != null && place.image!.isNotEmpty ? [place.image!] : <String>[]);
    final String heroImg = (imgs.isNotEmpty
            ? imgs.first
            : (place.image != null && place.image!.isNotEmpty ? place.image! : ''))
        .toString();
    final String headerUrl = heroImg.isNotEmpty ? heroImg : 'https://placehold.co/1200x600/png';
    final subtitle = (
      [place.category, if ((place.story ?? '').isNotEmpty) place.story]
          .whereType<String>()
          .where((e) => e.trim().isNotEmpty)
          .join(' - ')
    );

    final hasOpenLate = place.tags.map((e)=>e.toLowerCase()).any((t)=>t.contains('open_late'));
    final isBusy = place.tags.map((e)=>e.toLowerCase()).any((t)=>t.contains('busy') || t.contains('crowd'));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context)),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      headerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) => Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: -24,
                      child: Material(
                        elevation: 6,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              if (subtitle.isNotEmpty)
                                Text(subtitle, style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (hasOpenLate)
                                  _Badge(text: 'Open late', icon: Icons.nights_stay),
                                if (isBusy) ...[
                                  const SizedBox(width: 8),
                                  _Badge(text: 'Busy', icon: Icons.group),
                                ]
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              expandedHeight: 320,
            ),
            SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TabBar(
                      labelColor: Colors.red,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: Colors.red,
                      tabs: [
                        Tab(text: 'History'),
                        Tab(text: 'Personal Tips'),
                        Tab(text: 'Past Events'),
                      ],
                    ),
                    SizedBox(
                      height: 220,
                      child: TabBarView(children: [
                        _TabText(text: place.history ?? place.description),
                        _TabText(text: place.personalTips ?? 'No personal tips available.'),
                        _TabText(text: place.pastEvents ?? 'No past events information.'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    const Text('Nearby Recommendations', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: (place.nearbyRecommendations?.length ?? 0).clamp(0, 10),
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (c, i) {
                          final name = place.nearbyRecommendations![i];
                          return SizedBox(
                            width: 200,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 110,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.local_cafe)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_distanceLabel(place.lat, place.lng), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Similar Places', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 210,
                      child: FutureBuilder<List<Place>>(
                        future: ApiService().similar(place.id, k: 8),
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = snap.data ?? const <Place>[];
                          if (items.isEmpty) return const Center(child: Text('No similar places yet'));
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (c2, j) {
                              final p = items[j];
                              return SizedBox(
                                width: 220,
                                child: PlaceCard(
                                  place: p,
                                  onTap: () {
                                    Navigator.push(c2, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final pos = await _getCurrentPosition(context);
                    if (pos == null) return;
                    final api = ApiService();
                    try {
                      final prefs = prefsNotifier.value;
                      final inferred = prefs.toRoutePayload();
                      final data = await api.routeSuggestions(
                        userId: 'A123',
                        userLat: pos.latitude,
                        userLng: pos.longitude,
                        destLat: place.lat,
                        destLng: place.lng,
                        thresholdKm: 1.2,
                        k: 5,
                        transportMode: prefs.transportMode,
                        pace: prefs.pace,
                        availableTimeMin: prefs.availableTimeMin,
                        walkingDistanceKm: prefs.walkingDistanceKm,
                        intent: inferred['intent'] as String?,
                      );
                      if (context.mounted) {
                        _showRouteSheet(context, data);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Route suggestions failed')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Directions'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: FavoritesStore.instance.favorites,
                  builder: (context, favs, _) {
                    final saved = FavoritesStore.instance.isFavorite(place);
                    return OutlinedButton.icon(
                      onPressed: () async {
                        await FavoritesStore.instance.toggle(place);
                        final nowSaved = FavoritesStore.instance.isFavorite(place);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(nowSaved ? 'Saved to favorites' : 'Removed from saved')),
                        );
                      },
                      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_add_outlined),
                      label: Text(saved ? 'Saved' : 'Save'),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final items = await ApiService().similar(place.id, k: 8);
                    if (!context.mounted) return;
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (c) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Similar Places', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                if (items.isEmpty) const Text('No similar places yet'),
                                for (final p in items)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: (p.image != null && p.image!.isNotEmpty)
                                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.image!, width: 48, height: 48, fit: BoxFit.cover))
                                      : const Icon(Icons.place),
                                    title: Text(p.name),
                                    subtitle: Text(p.category),
                                    onTap: (){
                                      Navigator.of(c).pop();
                                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Find Similar'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<Position?> _getCurrentPosition(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get location')),
      );
      return null;
    }
  }

  void _showRouteSheet(BuildContext rootContext, Map<String, dynamic> data) {
    final narration = data['narration']?.toString() ?? '';
    final List<dynamic> items = (data['suggestions'] as List?) ?? const [];
    showModalBottomSheet(
      context: rootContext,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (narration.isNotEmpty) ...[
                  Text(narration, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty) const Text('No suggestions on your route'),
                for (final it in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(it['name']?.toString() ?? ''),
                    subtitle: Text('~${it['route_distance_km']?.toString()} km off route'),
                    onTap: () {
                      Navigator.of(c).pop();
                      final p = Place.fromJson(Map<String, dynamic>.from(it as Map));
                      Navigator.of(rootContext).push(
                        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)),
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapSection extends StatelessWidget {
  final double lat;
  final double lng;
  const _MapSection({required this.lat, required this.lng});

  bool get _valid => lat != 0 && lng != 0 && lat.abs() <= 90 && lng.abs() <= 180;

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return Container(
        height: 180,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('No map available')),
      );
    }
    final center = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 14),
          markers: {
            Marker(markerId: const MarkerId('place'), position: center),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}


class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Badge({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Icon(icon, size: 14, color: Colors.green), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 12))]),
    );
  }
}

class _TabText extends StatelessWidget {
  final String text;
  const _TabText({required this.text});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text, style: const TextStyle(height: 1.4)),
    );
  }
}
