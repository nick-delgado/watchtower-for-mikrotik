import 'package:flutter/material.dart';

import 'home_screen.dart';

class WatchtowerApp extends StatelessWidget {
  const WatchtowerApp({super.key});

  static const _seed = Color(0xFF3949AB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watchtower',
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
