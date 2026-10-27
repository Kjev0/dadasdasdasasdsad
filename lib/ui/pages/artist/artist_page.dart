// STUB(ui-pages)
// Minimal placeholder created by ui-foundation so the router compiles.
// The ui-pages agent replaces this file (keep the class name/constructor).
import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class ArtistPage extends StatelessWidget {
  const ArtistPage({super.key, required this.sourceId, required this.artistId});

  final String sourceId;

  final String artistId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).navLibrary)),
    );
  }
}
