import 'package:flutter/material.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const KolkataTourApp());
}

class KolkataTourApp extends StatelessWidget {
  const KolkataTourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kolkata Tour AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
