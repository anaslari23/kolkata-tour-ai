import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../services/api.dart';
import 'place_details_screen.dart';
import '../config.dart';
import '../widgets/prefs_sheet.dart';
import '../state/prefs.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final api = const ApiService();
  List<Place> places = const [];
  bool loading = true;
  String? error;
  GoogleMapController? _ctrl;
  bool _myLocEnabled = false;
  String _typeFilter = 'All';
  final List<String> _filters = const ['All','Food','History','Art','Parks','Religious','Landmark'];
  String _query = '';
  final PageController _pageCtrl = PageController(viewportFraction: 0.86);
  int _currentIdx = 0;

  @override
  void initState() {
    super.initState();
    // load saved preferences
    loadPrefs();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
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

  Future<void> _load() async {
    setState(()=>loading=true);
    try {
      final res = await api.getPlaces(city: 'Kolkata');
      setState(() { places = res; error = null; });
    } catch (e) {
      setState(() { error = 'Failed to load places'; });
    } finally {
      if (mounted) setState(()=>loading=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = places.where((p){
      final okCoords = p.lat!=0 && p.lng!=0;
      if (!okCoords) return false;
      final typeOk = _typeFilter == 'All' || (p.category.toLowerCase().contains(_typeFilter.toLowerCase())) || (p.tags.any((t)=>t.toLowerCase().contains(_typeFilter.toLowerCase())));
      final qOk = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase()) || p.category.toLowerCase().contains(_query.toLowerCase());
      return typeOk && qOk;
    }).toList();

    // Clamp current carousel index to valid range after filtering
    if (_currentIdx >= filtered.length) {
      _currentIdx = 0;
      if (_pageCtrl.hasClients && filtered.isNotEmpty) {
        try {
          _pageCtrl.jumpToPage(0);
        } catch (_) {}
      }
    }

    final markers = <Marker>{};
    for (final p in filtered) {
      final m = Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.lat, p.lng),
        infoWindow: InfoWindow(title: p.name, snippet: p.category, onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (_)=>PlaceDetailsScreen(place: p)));
        }),
      );
      markers.add(m);
    }

    final initial = (filtered.isNotEmpty ? filtered : places).firstWhere(
      (p)=>p.lat!=0&&p.lng!=0,
      orElse: ()=> const Place(id: '0', name: 'Kolkata', category: '', description: '', images: [], tags: [], lat: 22.5726, lng: 88.3639)
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kolkata Map'),
        actions: [IconButton(onPressed: () => showPrefsSheet(context), icon: const Icon(Icons.tune))],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(initial.lat, initial.lng), zoom: 12.5),
              markers: markers,
              onMapCreated: (c)=>_ctrl=c,
              myLocationEnabled: _myLocEnabled,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
          // Top overlay: search + filters
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(24),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search places on map',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v){ setState(()=>_query=v); },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (c, i){
                        final f = _filters[i];
                        final sel = f == _typeFilter;
                        return ChoiceChip(
                          label: Text(f),
                          selected: sel,
                          onSelected: (_){ setState(()=>_typeFilter=f); },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const Positioned.fill(child: IgnorePointer(child: Center(child: CircularProgressIndicator()))),
          if (error != null && !loading)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ),
              ),
            ),
          // Bottom swipable carousel of places (anchored)
          (filtered.isNotEmpty)
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 170,
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: filtered.length,
                        padEnds: false,
                        onPageChanged: (i) {
                          _currentIdx = i;
                          if (i >= 0 && i < filtered.length) {
                            final p = filtered[i];
                            if (_ctrl != null) {
                              Future.microtask(() {
                                if (!mounted) return;
                                _ctrl?.animateCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: LatLng(p.lat, p.lng),
                                      zoom: 15.0,
                                      tilt: 0,
                                      bearing: 0,
                                    ),
                                  ),
                                );
                              });
                            }
                          }
                        },
                        itemBuilder: (c, i) {
                          final p = filtered[i];
                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 16 : 12, right: 12),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_)=>PlaceDetailsScreen(place: p)));
                              },
                              child: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1,
                                      child: Image.network(
                                        p.images.isNotEmpty ? p.images.first : '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, st) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_outlined)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 4),
                                            Text(p.category, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: const [
                                                Icon(Icons.place, size: 14, color: Colors.teal),
                                                SizedBox(width: 4),
                                                Text('View on map', style: TextStyle(fontSize: 12, color: Colors.teal)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          // Optional bottom gradient scrim for contrast
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x66000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'loc',
            onPressed: () async {
              final pos = await _getCurrentPosition(context);
              final lat = pos?.latitude ?? DEV_LAT;
              final lng = pos?.longitude ?? DEV_LNG;
              if (_ctrl != null) {
                setState(()=>_myLocEnabled=true);
                _ctrl!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.5));
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'reload',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
        ],
      ),
    );
  }
}
