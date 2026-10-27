import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/library.dart';
import '../../../core/models/matching.dart';
import '../../../core/models/track.dart';
import '../../../core/util/cancel_token.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/search_field.dart';
import '../../widgets/dialogs/sheet.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/tracks/track_format.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/import_helpers.dart';
import '../library/shared/revisions.dart';
import '../library/shared/track_helpers.dart';
import 'playlist_providers.dart';

/// Linked matches of [Track] (`TrackLinkRepository.linkedTracks`).
final trackLinksProvider = FutureProvider.autoDispose.family<List<(Track, TrackLink)>, String>(
  (ref, trackId) async {
    watchLibrary(ref, LibraryTopic.links);
    return ref.watch(trackLinkRepositoryProvider).linkedTracks(trackId);
  },
  retry: noRetry,
);

/// Automatic candidates from the matcher for an original track.
final matchCandidatesProvider = FutureProvider.autoDispose.family<TrackMatchResult, Track>(
  (ref, original) async {
    final options = matchOptionsFor(ref.read(settingsProvider), ref.read(sourceRegistryProvider), originSource: original.sourceId);
    return ref.watch(trackMatcherProvider).findMatches(original, options, cancel: providerCancelToken(ref));
  },
  retry: noRetry,
);

/// Opens "Find alternatives" for an imported / unplayable track.
Future<void> showAlternativesSheet(BuildContext context, Track original) =>
    showFermataSheet<void>(context, maxWidth: 720, builder: (_) => AlternativesSheet(original: original));

String confidenceLabel(AppLocalizations l10n, MatchConfidence c) => switch (c) {
      MatchConfidence.exact => l10n.matchExact,
      MatchConfidence.high => l10n.matchHigh,
      MatchConfidence.medium => l10n.matchMedium,
      MatchConfidence.low => l10n.matchLow,
      MatchConfidence.none => l10n.matchNone,
    };

/// Shows current links and match candidates on other sources; "Use" links
/// the candidate (user-confirmed) so the stream resolver plays it instead.
class AlternativesSheet extends ConsumerStatefulWidget {
  const AlternativesSheet({super.key, required this.original});

  final Track original;

  @override
  ConsumerState<AlternativesSheet> createState() => _AlternativesSheetState();
}

class _AlternativesSheetState extends ConsumerState<AlternativesSheet> {
  final _latest = LatestOnly();
  List<MatchCandidate>? _manual;
  bool _searching = false;

  @override
  void dispose() {
    _latest.cancel();
    super.dispose();
  }

  Track get original => widget.original;

  /// Manual search on the import targets, scored against the original.
  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final token = _latest.next();
    setState(() => _searching = true);
    final settings = ref.read(settingsProvider);
    final registry = ref.read(sourceRegistryProvider);
    final scorer = ref.read(trackScorerProvider);
    final targets = importTargets(settings, registry, originSource: original.sourceId).toSet();
    final found = <MatchCandidate>[];
    try {
      await for (final r in registry.searchAll(q, types: const {SearchType.tracks}, onlySources: targets, cancel: token)) {
        for (final t in r.tracks.items) {
          found.add(scorer.score(original, t));
        }
      }
    } catch (_) {
      // Per-source failures arrive as results; anything else ends the search.
    }
    if (!mounted || token.isCanceled) return;
    found.sort((a, b) => b.score.compareTo(a.score));
    setState(() {
      _manual = found;
      _searching = false;
    });
  }

  Future<void> _use(MatchCandidate c) async {
    final l10n = context.l10n;
    try {
      await ref.read(trackRepositoryProvider).upsertTracks([c.candidate]);
      await ref.read(trackLinkRepositoryProvider).link(original.id, c.candidate.id, confidence: c.score, userConfirmed: true);
      ref.invalidate(trackLinksProvider(original.id));
      ref.invalidate(playlistLinksProvider);
      if (mounted) showFermataToast(context, l10n.alternativesLinked(sourceDisplayName(ref, c.candidate.sourceId)), icon: Icons.link_rounded);
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
  }

  Future<void> _unlink(Track linked) async {
    try {
      await ref.read(trackLinkRepositoryProvider).unlink(original.id, linked.id);
      ref.invalidate(trackLinksProvider(original.id));
      ref.invalidate(playlistLinksProvider);
    } catch (e) {
      if (mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
    }
  }

  Widget _candidateTile(MatchCandidate c, Set<String> linkedIds) {
    final l10n = context.l10n;
    final t = c.candidate;
    final linked = linkedIds.contains(t.id);
    final diffs = [for (final d in c.differences) matchDifferenceLabel(l10n, d)];
    return ListTile(
      key: ValueKey('candidate-${t.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [t.artistLine, if (t.duration != null) formatDuration(t.duration!)].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              SourceChip(sourceId: t.sourceId, dense: true),
              Text(l10n.alternativesScore((c.score * 100).round(), confidenceLabel(l10n, c.confidence)), style: context.type.caption),
              if (!isPlayableInApp(t)) AvailabilityBadge.forTrack(t, dense: true),
              if (diffs.isNotEmpty) Text(diffs.join(', '), style: context.type.caption.copyWith(color: context.colors.warning)),
            ],
          ),
        ],
      ),
      trailing: linked
          ? Icon(Icons.check_circle_rounded, color: context.colors.success, semanticLabel: l10n.alternativesInUse)
          : TextButton(onPressed: () => _use(c), child: Text(l10n.alternativesUse)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final links = ref.watch(trackLinksProvider(original.id));
    final auto = ref.watch(matchCandidatesProvider(original));
    final linkedIds = {for (final l in links.value ?? const <(Track, TrackLink)>[]) l.$1.id};
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.alternativesTitle, style: context.type.title),
                const SizedBox(height: 4),
                Text('${original.title} · ${original.artistLine}', style: context.type.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (original.availability.reason != null || !isPlayableInApp(original))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isExternalTrack(original)
                          ? l10n.shellBadgeExternal(sourceDisplayName(ref, original.sourceId))
                          : availabilityReasonText(l10n, original.availability.reason),
                      style: context.type.caption,
                    ),
                  ),
              ],
            ),
          ),
          if ((links.value ?? const []).isNotEmpty) ...[
            _heading(l10n.alternativesLinkedNow),
            for (final (t, link) in links.value!)
              ListTile(
                key: ValueKey('linked-${t.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(link.userConfirmed ? Icons.verified_rounded : Icons.link_rounded),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${t.artistLine} · ${sourceDisplayName(ref, t.sourceId)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(onPressed: () => _unlink(t), child: Text(l10n.alternativesUnlink)),
              ),
          ],
          _heading(l10n.alternativesSuggested),
          auto.when(
            loading: () => const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()),
            error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(matchCandidatesProvider(original))),
            data: (result) => result.candidates.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text(l10n.alternativesNone, style: context.type.bodySmall))
                : Column(children: [for (final c in result.candidates) _candidateTile(c, linkedIds)]),
          ),
          _heading(l10n.alternativesSearch),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchField(
              key: const ValueKey('alternatives-search'),
              hint: l10n.alternativesSearchHint,
              onSubmitted: _search,
            ),
          ),
          if (_searching) const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator()),
          if (_manual != null && !_searching)
            _manual!.isEmpty
                ? Padding(padding: const EdgeInsets.all(20), child: Text(l10n.alternativesNone, style: context.type.bodySmall))
                : Column(children: [for (final c in _manual!) _candidateTile(c, linkedIds)]),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(text, style: context.type.label.copyWith(color: context.colors.accentText)),
      );
}

String matchDifferenceLabel(AppLocalizations l10n, MatchDifference d) => switch (d) {
      MatchDifference.remix => l10n.diffRemix,
      MatchDifference.live => l10n.diffLive,
      MatchDifference.acoustic => l10n.diffAcoustic,
      MatchDifference.extended => l10n.diffExtended,
      MatchDifference.radioEdit => l10n.diffRadioEdit,
      MatchDifference.instrumental => l10n.diffInstrumental,
      MatchDifference.karaoke => l10n.diffKaraoke,
      MatchDifference.cover => l10n.diffCover,
      MatchDifference.remaster => l10n.diffRemaster,
      MatchDifference.sped => l10n.diffSped,
      MatchDifference.slowed => l10n.diffSlowed,
      MatchDifference.demo => l10n.diffDemo,
      MatchDifference.explicitMismatch => l10n.diffExplicit,
      MatchDifference.durationMismatch => l10n.diffDuration,
      MatchDifference.albumMismatch => l10n.diffAlbum,
      MatchDifference.yearMismatch => l10n.diffYear,
      MatchDifference.artistMismatch => l10n.diffArtist,
      MatchDifference.featuredArtistMismatch => l10n.diffFeatured,
      MatchDifference.titleMismatch => l10n.diffTitle,
      MatchDifference.previewOnly => l10n.diffPreview,
    };
