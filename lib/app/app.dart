import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session.dart';
import 'root_screen.dart';

class WatchtowerApp extends ConsumerStatefulWidget {
  const WatchtowerApp({super.key});

  @override
  ConsumerState<WatchtowerApp> createState() => _WatchtowerAppState();
}

class _WatchtowerAppState extends ConsumerState<WatchtowerApp> {
  static const _seed = Color(0xFF3949AB);

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Closes the router connection while the app is hidden and reconnects
    // when it comes back.
    _lifecycle = AppLifecycleListener(
      onShow: () => ref.read(appActiveProvider.notifier).set(true),
      onHide: () => ref.read(appActiveProvider.notifier).set(false),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watchtower',
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: const RootScreen(),
    );
  }
}
