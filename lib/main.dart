import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';

Future<void> main(List<String> args) async {
  try {
    final boot = await bootstrap(args);
    runApp(ProviderScope(overrides: serviceOverrides(boot.services), child: const FermataApp()));
  } catch (e, st) {
    Logger('app.main').severe('Startup failed', e, st);
    runApp(_StartupErrorApp(error: e));
  }
}

/// Shown only when the app cannot start at all (e.g. a database written by a
/// newer version). Never shown during normal operation.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0C0C0E)),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fermata could not start', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
