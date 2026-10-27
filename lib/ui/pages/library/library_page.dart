// STUB(ui-pages)
// Minimal placeholder created by ui-foundation so the router compiles.
// The ui-pages agent replaces this file (keep the class name/constructor).
import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).navLibrary)),
    );
  }
}
