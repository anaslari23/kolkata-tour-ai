import 'package:flutter/material.dart';
// Removed mock data usage so lists start empty

class FavoritesHistoryScreen extends StatefulWidget {
  const FavoritesHistoryScreen({super.key});

  @override
  State<FavoritesHistoryScreen> createState() => _FavoritesHistoryScreenState();
}

class _FavoritesHistoryScreenState extends State<FavoritesHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Favorites & History', style: TextStyle(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.amber,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.black54,
          tabs: const [Tab(text: 'Favorites'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const _List(
            items: <_Item>[],
            showFooter: false,
          ),
          const _List(
            items: <_Item>[],
            showFooter: false,
          ),
        ],
      ),
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  final String img;
  const _Item({required this.title, required this.subtitle, required this.img});
}

class _List extends StatelessWidget {
  final List<_Item> items;
  final bool showFooter;
  const _List({required this.items, this.showFooter = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c,i){
        if (showFooter && i == items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: const [
                SizedBox(height: 16),
                Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No More Favorites', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text(
                  "You've reached the end of your saved places.\nTap the heart icon on a place's page to save it!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        final it = items[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: SizedBox(
              width: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  it.img,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, st) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
            title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(it.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.more_vert),
          ),
        );
      },
    );
  }
}
