// STUB(ui-pages)
// Minimal placeholder created by ui-foundation so the router compiles.
// The ui-pages agent replaces this file (keep the class name/constructor).
import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).navPlaylists)),
    );
  }
}
