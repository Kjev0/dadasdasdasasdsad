import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../../app/providers.dart';
import '../../../../core/models/track.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/feedback/toast.dart';
import '../shared/page_layout.dart';

final _log = Logger('ui.pages.tags');

/// Builds the edited copy of [original] (empty fields clear the value).
Track editedTrack(
  Track original, {
  required String title,
  required String artists,
  required String album,
  required String albumArtist,
  required String year,
  required String genre,
  required String trackNumber,
  required String discNumber,
}) {
  String? opt(String v) => v.trim().isEmpty ? null : v.trim();
  final names = [for (final n in artists.split(RegExp(r'[;,]'))) if (n.trim().isNotEmpty) n.trim()];
  // Keep provider artist ids for names that did not change.
  final byName = {for (final a in original.artists) a.name: a};
  return Track(
    sourceId: original.sourceId,
    sourceTrackId: original.sourceTrackId,
    title: title.trim().isEmpty ? original.title : title.trim(),
    artists: [for (final n in names) byName[n] ?? ArtistRef(n)],
    album: opt(album),
    albumArtist: opt(albumArtist),
    duration: original.duration,
    isrc: original.isrc,
    explicit: original.explicit,
    year: int.tryParse(year.trim()),
    genre: opt(genre),
    trackNumber: int.tryParse(trackNumber.trim()),
    discNumber: int.tryParse(discNumber.trim()),
    artworkUrl: original.artworkUrl,
    permalink: original.permalink,
    localPath: original.localPath,
    availability: original.availability,
    format: original.format,
    replayGainTrackDb: original.replayGainTrackDb,
    replayGainAlbumDb: original.replayGainAlbumDb,
    extra: original.extra,
  );
}

/// Edits the tags of a local track via `LocalLibraryService.editTags`.
/// Where the file can't be written (format / platform), the edit is kept
/// as a non-destructive library override, and the dialog says so.
class TagEditorDialog extends ConsumerStatefulWidget {
  const TagEditorDialog({super.key, required this.track});

  final Track track;

  /// Returns true when the tags were saved.
  static Future<bool> show(BuildContext context, Track track) async =>
      await showDialog<bool>(context: context, builder: (_) => TagEditorDialog(track: track)) ?? false;

  @override
  ConsumerState<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends ConsumerState<TagEditorDialog> {
  late final Track t = widget.track;
  late final _title = TextEditingController(text: t.title);
  late final _artists = TextEditingController(text: t.artists.map((a) => a.name).join('; '));
  late final _album = TextEditingController(text: t.album ?? '');
  late final _albumArtist = TextEditingController(text: t.albumArtist ?? '');
  late final _year = TextEditingController(text: t.year?.toString() ?? '');
  late final _genre = TextEditingController(text: t.genre ?? '');
  late final _trackNo = TextEditingController(text: t.trackNumber?.toString() ?? '');
  late final _discNo = TextEditingController(text: t.discNumber?.toString() ?? '');
  bool _saving = false;

  List<TextEditingController> get _all => [_title, _artists, _album, _albumArtist, _year, _genre, _trackNo, _discNo];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    final edited = editedTrack(
      t,
      title: _title.text,
      artists: _artists.text,
      album: _album.text,
      albumArtist: _albumArtist.text,
      year: _year.text,
      genre: _genre.text,
      trackNumber: _trackNo.text,
      discNumber: _discNo.text,
    );
    try {
      final written = await ref.read(localLibraryProvider).editTags(t, edited);
      if (!mounted) return;
      showFermataToast(
        context,
        written ? l10n.libraryTagsSavedToFile : l10n.libraryTagsSavedAsOverride,
        icon: written ? Icons.save_rounded : Icons.bookmark_added_rounded,
      );
      Navigator.of(context).pop(true);
    } catch (e, st) {
      _log.warning('Tag edit failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
  }

  Widget _field(TextEditingController c, String label, {bool number = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)] : null,
          decoration: InputDecoration(labelText: label, helperText: hint, isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileWritable = ref.watch(localLibraryProvider).supportsFileTagWriting;
    final compact = isCompactWidth(context);
    Widget pair(Widget a, Widget b) => compact
        ? Column(children: [a, b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
    return AlertDialog(
      title: Text(l10n.libraryEditTags),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InlineNotice(
                key: const ValueKey('tag-write-notice'),
                icon: fileWritable ? Icons.info_outline_rounded : Icons.bookmark_rounded,
                message: fileWritable ? l10n.libraryTagsFileHint : l10n.libraryTagsOverrideOnly,
              ),
              const SizedBox(height: 16),
              _field(_title, l10n.libraryTagTitle),
              _field(_artists, l10n.libraryTagArtists, hint: l10n.libraryTagArtistsHint),
              pair(_field(_album, l10n.libraryTagAlbum), _field(_albumArtist, l10n.libraryTagAlbumArtist)),
              pair(_field(_year, l10n.libraryTagYear, number: true), _field(_genre, l10n.libraryTagGenre)),
              pair(_field(_trackNo, l10n.libraryTagTrackNumber, number: true), _field(_discNo, l10n.libraryTagDiscNumber, number: true)),
            ],
          ),
        ),
      ),
      actions: [
        FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: () => Navigator.of(context).pop(false)),
        FermataButton(label: l10n.actionSave, busy: _saving, onPressed: _save),
      ],
    );
  }
}
