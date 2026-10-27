import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/models/auth.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/matching.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../settings/services/source_card.dart' show connectionStatusLabel;
import '../settings/widgets/setting_tiles.dart';

/// Sources a playlist can be imported from.
bool canImportFrom(MusicSource s) =>
    s.supports(SourceCapability.playlistImport) || s.supports(SourceCapability.userLibrary);

/// Step 1: choose where the playlist comes from.
class ImportSourceStep extends ConsumerWidget {
  const ImportSourceStep({super.key, required this.onSource, required this.onM3u});

  final ValueChanged<MusicSource> onSource;
  final VoidCallback onM3u;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(sourcesRevisionProvider);
    final sources = [for (final s in ref.watch(sourceRegistryProvider).ordered) if (canImportFrom(s)) s];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.importChooseSource, style: context.type.title),
        const SizedBox(height: 4),
        Text(l10n.importChooseSourceHint, style: context.type.bodySmall),
        const SizedBox(height: 16),
        for (final s in sources) _SourceOption(source: s, onSelect: () => onSource(s)),
        _OptionCard(
          key: const ValueKey('import.source.m3u'),
          icon: Icons.insert_drive_file_outlined,
          title: l10n.importM3uTitle,
          subtitle: l10n.importM3uHint,
          onTap: onM3u,
        ),
      ],
    );
  }
}

class _SourceOption extends ConsumerStatefulWidget {
  const _SourceOption({required this.source, required this.onSelect});

  final MusicSource source;
  final VoidCallback onSelect;

  @override
  ConsumerState<_SourceOption> createState() => _SourceOptionState();
}

class _SourceOptionState extends ConsumerState<_SourceOption> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      await widget.source.connect();
    } catch (e) {
      if (mounted) {
        final msg = errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric;
        showFermataToast(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.source;
    return StreamBuilder<SourceAuthState>(
      stream: s.authStateChanges,
      initialData: s.authState,
      builder: (context, snap) {
        final auth = snap.data ?? s.authState;
        final configured = s.credentialStatus.configured;
        final needsAccount = s.supports(SourceCapability.oauth) && !auth.isConnected;
        // Public playlists can be imported by link without an account.
        final usable = configured && (!needsAccount || s.supports(SourceCapability.playlistImport));
        final subtitle = !configured
            ? l10n.importSourceNotSetUp(s.displayName)
            : needsAccount
                ? (s.supports(SourceCapability.playlistImport) ? l10n.importSourceLinkOnly : l10n.importSourceConnectFirst)
                : (auth.accountName != null ? l10n.importSourceSignedIn(auth.accountName!) : connectionStatusLabel(l10n, auth.status));
        return _OptionCard(
          key: ValueKey('import.source.${s.id}'),
          icon: Icons.library_music_outlined,
          title: s.displayName,
          subtitle: subtitle,
          onTap: usable ? widget.onSelect : null,
          trailing: !configured
              ? FermataButton(
                  label: l10n.importSetUp,
                  variant: FermataButtonVariant.ghost,
                  onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.services)),
                )
              : needsAccount
                  ? FermataButton(
                      key: ValueKey('import.source.${s.id}.connect'),
                      label: l10n.settingsConnect,
                      variant: FermataButtonVariant.secondary,
                      busy: _connecting,
                      onPressed: _connect,
                    )
                  : null,
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: context.radii.mdAll, side: BorderSide(color: c.outlineSubtle)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: enabled ? c.accentText : c.textTertiary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.type.titleSmall.copyWith(color: enabled ? c.textPrimary : c.textTertiary)),
                  if (subtitle != null) Text(subtitle!, style: context.type.bodySmall),
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!] else if (enabled) Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The user's playlists on a connected source.
final userPlaylistsOfProvider = FutureProvider.autoDispose.family<List<Playlist>, String>((ref, sourceId) {
  final source = ref.watch(sourceRegistryProvider).require(sourceId);
  return source.userPlaylists();
});

/// Step 2 for a service: one of the user's playlists, liked tracks, or a link.
class ImportWhatStep extends ConsumerStatefulWidget {
  const ImportWhatStep({super.key, required this.source, required this.onPlaylist, required this.onLiked, required this.onLink});

  final MusicSource source;
  final ValueChanged<Playlist> onPlaylist;
  final VoidCallback onLiked;
  final ValueChanged<String> onLink;

  @override
  ConsumerState<ImportWhatStep> createState() => _ImportWhatStepState();
}

class _ImportWhatStepState extends ConsumerState<ImportWhatStep> {
  final _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _submitLink() {
    final v = _link.text.trim();
    if (v.isNotEmpty) widget.onLink(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.source;
    final connected = s.authState.isConnected;
    final library = s.supports(SourceCapability.userLibrary) && connected;
    final byLink = s.supports(SourceCapability.playlistImport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.importChooseWhat(s.displayName), style: context.type.title),
        const SizedBox(height: 16),
        if (byLink) ...[
          Text(l10n.importPasteLink, style: context.type.label),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('import.link'),
                controller: _link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(hintText: l10n.importPasteLinkHint(s.displayName)),
                onSubmitted: (_) => _submitLink(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            FermataButton(
              key: const ValueKey('import.link.continue'),
              label: l10n.importContinue,
              onPressed: _link.text.trim().isEmpty ? null : _submitLink,
            ),
          ]),
          const SizedBox(height: 24),
        ],
        if (library) ...[
          _OptionCard(
            key: const ValueKey('import.liked'),
            icon: Icons.favorite_border_rounded,
            title: l10n.importLikedTracks,
            subtitle: l10n.importLikedTracksHint(s.displayName),
            onTap: widget.onLiked,
          ),
          if (byLink) ...[
            const SizedBox(height: 8),
            Text(l10n.importYourPlaylists, style: context.type.label),
            const SizedBox(height: 8),
            ref.watch(userPlaylistsOfProvider(s.id)).when(
                  loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2)),
                  error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(userPlaylistsOfProvider(s.id))),
                  data: (lists) => lists.isEmpty
                      ? Padding(padding: const EdgeInsets.all(8), child: Text(l10n.importNoPlaylists, style: context.type.bodySmall))
                      : Column(children: [
                          for (final p in lists)
                            _OptionCard(
                              key: ValueKey('import.playlist.${p.id}'),
                              icon: Icons.queue_music_rounded,
                              title: p.name,
                              subtitle: p.trackCount == null ? null : l10n.importTrackCount(p.trackCount!),
                              onTap: () => widget.onPlaylist(p),
                            ),
                        ]),
                ),
          ],
        ] else if (s.supports(SourceCapability.userLibrary))
          SettingNote(text: l10n.importConnectForLibrary(s.displayName)),
      ],
    );
  }
}

/// A target can be searched now: ready and with developer credentials.
bool targetUsable(MusicSource s) => s.isReady && s.credentialStatus.configured;

/// One match target in the options step.
class ImportTarget {
  ImportTarget(this.source, {required this.enabled});

  final MusicSource source;
  bool enabled;
}

/// Step 3: targets and matching options.
class ImportOptionsStep extends StatelessWidget {
  const ImportOptionsStep({
    super.key,
    required this.summary,
    required this.targets,
    required this.onTargetsChanged,
    required this.reviewMode,
    required this.onReviewMode,
    required this.threshold,
    required this.onThreshold,
    required this.skipUnavailable,
    required this.onSkipUnavailable,
    required this.preferred,
    required this.onPreferred,
    required this.allowPreview,
    required this.onAllowPreview,
  });

  final String summary;
  final List<ImportTarget> targets;
  final VoidCallback onTargetsChanged;
  final ReviewMode reviewMode;
  final ValueChanged<ReviewMode> onReviewMode;
  final double threshold;
  final ValueChanged<double> onThreshold;
  final bool skipUnavailable;
  final ValueChanged<bool> onSkipUnavailable;
  final String? preferred;
  final ValueChanged<String?> onPreferred;
  final bool allowPreview;
  final ValueChanged<bool> onAllowPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final enabledTargets = [for (final t in targets) if (t.enabled) t.source];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.importOptionsTitle, style: context.type.title),
        const SizedBox(height: 4),
        Text(summary, style: context.type.bodySmall),
        const SizedBox(height: 16),
        SettingsGroup(
          title: l10n.importTargets,
          description: l10n.importTargetsHint,
          children: [
            if (targets.isEmpty) SettingNote(text: l10n.importNoTargets, tone: NoteTone.warning, inGroup: true),
            for (var i = 0; i < targets.length; i++)
              Padding(
                key: ValueKey('import.target.${targets[i].source.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(children: [
                  Checkbox(
                    value: targets[i].enabled && targetUsable(targets[i].source),
                    onChanged: targetUsable(targets[i].source)
                        ? (v) {
                            targets[i].enabled = v ?? false;
                            onTargetsChanged();
                          }
                        : null,
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(targets[i].source.displayName,
                          style: context.type.body.copyWith(color: targetUsable(targets[i].source) ? c.textPrimary : c.textTertiary)),
                      if (!targetUsable(targets[i].source)) Text(l10n.importTargetNotReady, style: context.type.caption),
                    ]),
                  ),
                  if (targets[i].source.supports(SourceCapability.previewOnly))
                    const Padding(padding: EdgeInsets.only(right: 4), child: AvailabilityBadge(kind: AvailabilityBadgeKind.preview, dense: true)),
                  IconButton(
                    tooltip: l10n.settingsMoveUp,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    onPressed: i == 0
                        ? null
                        : () {
                            targets.insert(i - 1, targets.removeAt(i));
                            onTargetsChanged();
                          },
                  ),
                  IconButton(
                    tooltip: l10n.settingsMoveDown,
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    onPressed: i == targets.length - 1
                        ? null
                        : () {
                            targets.insert(i + 1, targets.removeAt(i));
                            onTargetsChanged();
                          },
                  ),
                ]),
              ),
          ],
        ),
        SettingsGroup(title: l10n.importMatchingGroup, children: [
          SettingChoice<ReviewMode>(
            key: const ValueKey('import.reviewMode'),
            title: l10n.settingsReviewMode,
            value: reviewMode,
            forceDropdown: true,
            options: [
              SettingOption(ReviewMode.autoAcceptHigh, l10n.settingsReviewAuto, description: l10n.settingsReviewAutoHint),
              SettingOption(ReviewMode.reviewAll, l10n.settingsReviewAll, description: l10n.settingsReviewAllHint),
            ],
            onChanged: onReviewMode,
          ),
          SettingSlider(
            title: l10n.settingsAutoAcceptThreshold,
            value: threshold,
            min: 0.6,
            max: 1.0,
            divisions: 40,
            format: (v) => '${(v * 100).round()} %',
            disabledReason: l10n.settingsAutoAcceptThresholdDisabled,
            onChanged: reviewMode == ReviewMode.autoAcceptHigh ? (v) => onThreshold((v * 100).round() / 100) : null,
          ),
          SettingSwitch(
            title: l10n.settingsSkipUnavailable,
            subtitle: l10n.settingsSkipUnavailableHint,
            value: skipUnavailable,
            onChanged: onSkipUnavailable,
          ),
          SettingChoice<String>(
            title: l10n.settingsPreferredProvider,
            value: preferred != null && enabledTargets.any((t) => t.id == preferred) ? preferred! : '',
            forceDropdown: true,
            options: [
              SettingOption('', l10n.settingsNoPreference),
              for (final t in enabledTargets) SettingOption(t.id, t.displayName),
            ],
            onChanged: (v) => onPreferred(v.isEmpty ? null : v),
          ),
          SettingSwitch(
            key: const ValueKey('import.allowPreview'),
            title: l10n.settingsAllowPreviewOnly,
            subtitle: l10n.settingsAllowPreviewOnlyHint,
            value: allowPreview,
            onChanged: onAllowPreview,
          ),
        ]),
      ],
    );
  }
}

/// Number of enabled, ready targets.
int readyTargets(List<ImportTarget> targets) => targets.where((t) => t.enabled && targetUsable(t.source)).length;

/// Ordered ids of enabled, ready targets.
List<String> targetIds(List<ImportTarget> targets) => [for (final t in targets) if (t.enabled && targetUsable(t.source)) t.source.id];

/// Keeps target order/enabled state while (re)computing the eligible list.
List<ImportTarget> mergeTargets(List<ImportTarget> previous, List<MusicSource> eligible) {
  final byId = {for (final t in previous) t.source.id: t};
  final ordered = [
    for (final t in previous) if (eligible.any((s) => s.id == t.source.id)) t,
    for (final s in eligible) if (!byId.containsKey(s.id)) ImportTarget(s, enabled: targetUsable(s)),
  ];
  return ordered;
}

