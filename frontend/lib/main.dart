import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_flow.dart';

void main() {
  runApp(const KolkataTourApp());
}

class KolkataTourApp extends StatelessWidget {
  const KolkataTourApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    );
    final theme = base.copyWith(
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: base.appBarTheme.copyWith(centerTitle: true, elevation: 0),
      cardTheme: base.cardTheme.copyWith(shadowColor: Colors.black12, elevation: 1.5),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
      ),
      chipTheme: base.chipTheme.copyWith(side: BorderSide.none, backgroundColor: Colors.grey.shade200),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
      ),
    );
    return MaterialApp(
      title: 'Kolkata Tour AI',
      theme: theme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Future<bool>? _onboarded;

  @override
  void initState() {
    super.initState();
    _onboarded = _checkOnboarded();
  }

  Future<bool> _checkOnboarded() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('onboarded') == true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboarded,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == true ? const HomeShell() : const OnboardingFlow();
      },
    );
  }
}
