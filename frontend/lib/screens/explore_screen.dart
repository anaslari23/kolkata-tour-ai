import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/api.dart';
import '../widgets/widgets.dart';
import 'place_details_screen.dart';
import '../widgets/prefs_sheet.dart';
import '../state/prefs.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String query = '';
  String selected = 'All';
  final filters = const ['All','Food','History','Art','Parks','Religious','Landmark'];
  final api = const ApiService();
  List<Place> remote = const [];
  bool loading = false;
  String? error;

  List<Place> get results => remote;

  Future<void> _fetch() async {
    setState(()=>loading=true);
    try {
      final type = selected == 'All' ? null : selected;
      final res = await api.search(query: query.isEmpty ? 'Kolkata' : query, city: 'Kolkata', type: type);
      setState((){ remote = res; error = null; });
    } catch (e) {
      setState(()=>error = 'Backend unavailable');
    } finally {
      if (mounted) setState(()=>loading=false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadPrefs();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore Kolkata',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: () => showPrefsSheet(context), icon: const Icon(Icons.tune)),
          IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none_rounded))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarField(onChanged: (v){ setState(()=>query=v); _fetch(); }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilterChips(
                    options: filters,
                    selected: selected,
                    onSelected: (v){ setState(()=>selected=v); _fetch(); },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _fetch,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.swap_vert_rounded),
                  label: const Text('Nearby'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null && !loading)
              Expanded(child: Center(child: Text(error!))),
            if ((error == null) && !loading)
              Expanded(
              child: results.isEmpty
                ? const Center(child: Text('No places found'))
                : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.70,
                ),
                itemCount: results.length,
                itemBuilder: (c,i){
                  final p = results[i];
                  return PlaceCard(place: p, onTap: (){
                    Navigator.push(c, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
