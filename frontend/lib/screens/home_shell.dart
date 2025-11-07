import 'package:flutter/material.dart';
import 'explore_screen.dart';
import 'map_screen.dart';
import 'favorites_history_screen.dart';
import 'chat_screen.dart';
// import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  final List<StatefulWidget> pages = const [
    ExploreScreen(),
    MapScreen(),
    FavoritesHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Clamp index defensively in case of unexpected values
    if (index < 0 || index >= pages.length) {
      index = 0;
    }
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        // Because we inserted a pseudo "AI" tab at nav index 1 that opens Chat via push,
        // we need to offset the visual selection for pages after it.
        selectedIndex: index >= 1 ? index + 1 : index,
        onDestinationSelected: (i) {
          // Inserted AI as a middle tab (index 1). Selecting it opens Chat.
          if (i == 1) {
            // Keep current tab selected and open chat safely
            Future.microtask(() {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            });
            return;
          }
          final mapped = i > 1 ? i - 1 : i; // map around AI pseudo-tab
          setState(() => index = mapped);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.smart_toy_rounded), selectedIcon: Icon(Icons.smart_toy), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
        ],
      ),
    );
  }
}

