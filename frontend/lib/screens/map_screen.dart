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

  @override
  void initState() {
    super.initState();
    // load saved preferences
    loadPrefs();
    _load();
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
    final markers = <Marker>{};
    for (final p in places.where((p)=>p.lat!=0 && p.lng!=0)) {
      final m = Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.lat, p.lng),
        infoWindow: InfoWindow(title: p.name, snippet: p.category, onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (_)=>PlaceDetailsScreen(place: p)));
        }),
      );
      markers.add(m);
    }

    final initial = places.firstWhere(
      (p)=>p.lat!=0&&p.lng!=0,
      orElse: ()=> const Place(id: '0', name: 'Kolkata', category: '', description: '', images: [], tags: [], lat: 22.5726, lng: 88.3639)
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Kolkata Map'), actions: [
        IconButton(onPressed: () => showPrefsSheet(context), icon: const Icon(Icons.tune))
      ]),
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
