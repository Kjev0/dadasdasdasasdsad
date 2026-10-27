// STUB(ui-settings)
// Minimal placeholder created by ui-foundation so the router compiles.
// The ui-settings agent replaces this file (keep the class name/constructor).
import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).navImport)),
    );
  }
}
