import 'package:flutter/material.dart';
import 'dart:async';
import '../models/place.dart';
import '../services/api.dart';
import '../widgets/widgets.dart';
import 'place_details_screen.dart';
import '../widgets/prefs_sheet.dart';
import 'profile_screen.dart';
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
  Timer? _debounce;

  // MIX: hero callouts + vertical feature cards + one horizontal carousel
  final List<Map<String, String>> heroActions = const [
    {'label': 'Coffee', 'query': 'cafe coffee tea stall'},
    {'label': 'Calm', 'query': 'quiet calm peaceful park'},
  ];
  final List<Map<String, String>> featureDeck = const [
    {'label': 'Hidden Gems', 'query': 'hidden gem alley old street cozy'},
    {'label': 'Iconic Sunset', 'query': 'sunset river-view bridge iconic'},
    {'label': 'Street Food Run', 'query': 'street-food kathi roll phuchka chaat'},
  ];
  int featureIndex = 0;
  List<Place> featureRecs = const <Place>[];
  List<Place> forYou = const <Place>[];
  String? _forYouQuery;

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
    _warmupPrompts();
  }

  Future<void> _warmupPrompts() async {}

  Future<void> _runHero(String query) async {
    setState(() { loading = true; });
    try {
      final res = await api.search(query: query, city: 'Kolkata', k: 10);
      setState(() { forYou = res; _forYouQuery = query; error = null; });
    } catch (_) {
      setState(() { error = 'Backend unavailable'; });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  Future<void> _loadFeature(int i) async {
    try {
      final q = featureDeck[i]['query']!;
      final res = await api.search(query: q, city: 'Kolkata', k: 6);
      if (mounted) setState(() { featureRecs = res; });
    } catch (_) {
      if (mounted) setState(() { featureRecs = const <Place>[]; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.person, size: 18, color: Colors.teal),
            ),
          ),
        ),
        title: const Text(
          'Explore Kolkata',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: () => showPrefsSheet(context), icon: const Icon(Icons.tune)),
          IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none_rounded))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarField(onChanged: (v){
              setState(()=>query=v);
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 280), _fetch);
            }),
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
            Row(
              children: [
                for (final a in heroActions)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _runHero(a['query']!),
                      child: Container(
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              a['label'] == 'Coffee' ? Icons.local_cafe_rounded : Icons.spa_rounded,
                              color: Colors.teal.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(a['label']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: PageView.builder(
                onPageChanged: (i){ setState(()=>featureIndex=i); _loadFeature(i); },
                itemCount: featureDeck.length,
                controller: PageController(viewportFraction: 0.92),
                itemBuilder: (c, i){
                  final label = featureDeck[i]['label']!;
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade100, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              TextButton.icon(
                                onPressed: featureRecs.isEmpty ? null : (){
                                  setState(() { query = featureDeck[i]['query']!; });
                                  _fetch();
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('See all'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: featureRecs.isEmpty
                            ? Center(child: Text('Finding $label...'))
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: featureRecs.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemBuilder: (c2, j){
                                  final p = featureRecs[j];
                                  return SizedBox(
                                    width: 240,
                                    child: PlaceCard(place: p, onTap: (){
                                      Navigator.push(c2, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                                    }),
                                  );
                                },
                              ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (forYou.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('For you', style: TextStyle(fontWeight: FontWeight.w800)),
                  if (_forYouQuery != null)
                    TextButton(
                      onPressed: () { setState(() { query = _forYouQuery!; }); _fetch(); },
                      child: const Text('See all'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: forYou.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (c, i){
                    final p = forYou[i];
                    return SizedBox(
                      width: 220,
                      child: PlaceCard(place: p, onTap: (){
                        Navigator.push(c, MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)));
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null && !loading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 42, color: Colors.black26),
                    const SizedBox(height: 8),
                    Text(error!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _fetch, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                  ],
                ),
              ),
            if ((error == null) && !loading)
              Builder(
                builder: (context){
                  if (results.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search_off, size: 42, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('No places found'),
                        SizedBox(height: 8),
                        Text('Try different filters or keywords', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
