import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/prefs.dart';
import 'home_shell.dart';
import 'onboarding_page.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pc = PageController();
  final Set<String> _selected = <String>{'Historical Sites', 'Art & Culture', 'Hidden Gems'};

  Future<void> _finish() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('onboarded', true);
    // persist interests into prefs
    final AppPrefs p = prefsNotifier.value;
    p.interests = _selected.map((e) => e.toLowerCase()).toList();
    await savePrefs(p);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _next() {
    if (_pc.page == null) return;
    final int idx = _pc.page!.round();
    if (idx >= 2) {
      _finish();
    } else {
      _pc.animateToPage(idx + 1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: PageView(
          controller: _pc,
          physics: const ClampingScrollPhysics(),
          children: [
            _WelcomePage(onContinue: _next),
            _InterestsPage(
              selected: _selected,
              onToggle: (s) {
                setState(() {
                  if (_selected.contains(s)) {
                    _selected.remove(s);
                  } else {
                    _selected.add(s);
                  }
                });
              },
              onSkip: _next,
              onContinue: _next,
            ),
            _LocationPage(onEnable: _next, onLater: _finish),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onContinue;
  const _WelcomePage({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OnboardingPage(
      title: 'Kolkata Tour AI',
      subtitle: 'Your Personal AI Guide to the City of Joy',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.landscape_rounded, size: 96, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(height: 24),
          _FeatureTile(icon: Icons.smart_toy_rounded, title: 'AI–Powered Tours', subtitle: 'Personalized guidance for your trip'),
          const SizedBox(height: 12),
          _FeatureTile(icon: Icons.diamond_rounded, title: 'Hidden Gems', subtitle: 'Discover unique and underrated spots'),
          const SizedBox(height: 12),
          _FeatureTile(icon: Icons.offline_bolt_rounded, title: 'Offline Access', subtitle: 'Explore freely without needing data'),
        ],
      ),
      primaryText: 'Explore Kolkata',
      onPrimary: onContinue,
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber[700], size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InterestsPage extends StatelessWidget {
  final Set<String> selected;
  final void Function(String) onToggle;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  const _InterestsPage({required this.selected, required this.onToggle, required this.onContinue, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      'Historical Sites',
      'Street Food',
      'Temples & Worship',
      'Art & Culture',
      'Nature & Parks',
      'Photography Spots',
      'Shopping & Markets',
      'Hidden Gems',
    ];
    return OnboardingPage(
      title: 'Personalize Your\nJourney',
      subtitle: 'Select your interests to discover hidden gems.',
      body: GridView.builder(
        padding: const EdgeInsets.only(top: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: chips.length,
        itemBuilder: (context, i) {
          final label = chips[i];
          final isOn = selected.contains(label);
          return GestureDetector(
            onTap: () => onToggle(label),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOn ? Colors.amber : Theme.of(context).dividerColor, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.05),
                  ],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (isOn)
                    const Icon(Icons.check_circle, color: Colors.amber, size: 22),
                  if (isOn) const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white), maxLines: 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      primaryText: 'Continue',
      onPrimary: onContinue,
      secondaryText: 'Skip for now',
      onSecondary: onSkip,
    );
  }
}

class _LocationPage extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onLater;
  const _LocationPage({required this.onEnable, required this.onLater});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OnboardingPage(
      title: 'Unlock Your Kolkata\nAdventure',
      subtitle: 'Location access helps personalize recommendations and navigation.',
      body: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber[200]?.withOpacity(0.5),
            ),
            alignment: Alignment.center,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber[400],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.explore_rounded, size: 72, color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
      primaryText: 'Enable Location',
      onPrimary: onEnable,
      secondaryText: "I'll Do It Later",
      onSecondary: onLater,
    );
  }
}


