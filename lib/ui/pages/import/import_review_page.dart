// STUB(ui-settings)
// Minimal placeholder created by ui-foundation so the router compiles.
// The ui-settings agent replaces this file (keep the class name/constructor).
import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class ImportReviewPage extends StatelessWidget {
  const ImportReviewPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).navImport)),
    );
  }
}
