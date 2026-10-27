import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../core/errors.dart';
import '../../../../core/models/auth.dart';
import '../../../../core/sources/source_policies.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../actions/link_launcher.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/feedback/toast.dart';
import '../settings_hooks.dart';
import 'credentials_editor.dart';

final _log = Logger('ui.settings.services');

/// Localized connection status.
String connectionStatusLabel(AppLocalizations l10n, SourceConnectionStatus s) => switch (s) {
      SourceConnectionStatus.notRequired => l10n.settingsStatusNotRequired,
      SourceConnectionStatus.credentialsMissing => l10n.settingsStatusCredentialsMissing,
      SourceConnectionStatus.notConnected => l10n.settingsStatusNotConnected,
      SourceConnectionStatus.connecting => l10n.settingsStatusConnecting,
      SourceConnectionStatus.connected => l10n.settingsStatusConnected,
      SourceConnectionStatus.expired => l10n.settingsStatusExpired,
      SourceConnectionStatus.error => l10n.settingsStatusError,
    };

/// What Fermata can do with [source] (positive list).
List<String> sourceAbilities(AppLocalizations l10n, MusicSource source) {
  bool has(SourceCapability c) => source.supports(c);
  return [
    if (has(SourceCapability.searchTracks) || has(SourceCapability.searchArtists)) l10n.settingsCanSearch,
    if (has(SourceCapability.stream) && !has(SourceCapability.previewOnly)) l10n.settingsCanStream,
    if (has(SourceCapability.previewOnly)) l10n.settingsCanPreview,
    if (has(SourceCapability.externalPlayback)) l10n.settingsCanExternal(source.displayName),
    if (has(SourceCapability.download)) l10n.settingsCanDownload,
    if (has(SourceCapability.userLibrary)) l10n.settingsCanLibrary,
    if (has(SourceCapability.playlistImport)) l10n.settingsCanImport,
    if (has(SourceCapability.isrcLookup)) l10n.settingsCanIsrc,
    if (has(SourceCapability.relatedTracks) || has(SourceCapability.trending) || has(SourceCapability.newReleases))
      l10n.settingsCanDiscover,
  ];
}

/// What Fermata cannot do with [source] (honest limits).
List<String> sourceLimits(AppLocalizations l10n, MusicSource source) {
  bool has(SourceCapability c) => source.supports(c);
  final policy = SourcePolicies.of(source.id);
  return [
    if (!has(SourceCapability.stream) || has(SourceCapability.previewOnly)) l10n.settingsCantStream,
    if (!has(SourceCapability.download) || !policy.allowsAnyDownload) l10n.settingsCantDownload,
    if (policy.siloedPlayback) l10n.settingsSiloed(source.displayName),
    if (!has(SourceCapability.userLibrary) && has(SourceCapability.oauth)) l10n.settingsCantLibrary,
  ];
}

/// One card in Settings → Connected services: status, account, scopes,
/// abilities and limits, terms link, connect/disconnect and the developer
/// credentials editor.
class SourceCard extends ConsumerStatefulWidget {
  const SourceCard({super.key, required this.source});

  final MusicSource source;

  @override
  ConsumerState<SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends ConsumerState<SourceCard> {
  bool _connecting = false;
  bool _canceled = false;
  bool _editCredentials = false;

  MusicSource get _source => widget.source;

  Future<void> _connect() async {
    final l10n = context.l10n;
    setState(() {
      _connecting = true;
      _canceled = false;
    });
    try {
      await _source.connect();
      if (mounted && !_canceled) showFermataToast(context, l10n.settingsConnected(_source.displayName), icon: Icons.check_rounded);
    } catch (e) {
      _log.info('Connecting ${_source.id} failed: ${e.runtimeType}');
      if (mounted && !_canceled) {
        final registry = ref.read(sourceRegistryProvider);
        final message = errorMessageFor(l10n, e, sourceName: (id) => registry.byId(id)?.displayName ?? id);
        if (message != null) {
          showFermataToast(context, e is FermataException ? message : l10n.settingsConnectFailed(_source.displayName), isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _cancel() {
    ref.read(settingsHooksProvider).cancelPendingSignIn?.call();
    setState(() {
      _canceled = true;
      _connecting = false;
    });
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.settingsDisconnectTitle(_source.displayName),
      message: l10n.settingsDisconnectBody(_source.displayName),
      confirmLabel: l10n.settingsDisconnect,
      destructive: true,
    );
    if (!ok) return;
    try {
      await _source.disconnect();
    } catch (_) {
      if (mounted) showFermataToast(context, l10n.errorGeneric, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when credentials change (the source's credential status follows).
    ref.watch(_credentialChangesProvider);
    return StreamBuilder<SourceAuthState>(
      stream: _source.authStateChanges,
      initialData: _source.authState,
      builder: (context, snap) => _buildCard(context, snap.data ?? _source.authState),
    );
  }

  Widget _buildCard(BuildContext context, SourceAuthState auth) {
    final l10n = context.l10n;
    final c = context.colors;
    final cred = _source.credentialStatus;
    final oauth = _source.supports(SourceCapability.oauth);
    final status = !cred.configured ? SourceConnectionStatus.credentialsMissing : auth.status;
    final connecting = _connecting || (status == SourceConnectionStatus.connecting && !_canceled);
    final statusColor = switch (status) {
      SourceConnectionStatus.connected || SourceConnectionStatus.notRequired => c.success,
      SourceConnectionStatus.credentialsMissing || SourceConnectionStatus.expired => c.warning,
      SourceConnectionStatus.error => c.danger,
      _ => c.textSecondary,
    };
    final abilities = sourceAbilities(l10n, _source);
    final limits = sourceLimits(l10n, _source);
    final showEditor = !cred.configured || _editCredentials;
    final needsCredentials = cred.missing.isNotEmpty || !cred.configured || cred.origin != CredentialOrigin.none;

    return Container(
      key: ValueKey('settings.source.${_source.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: context.radii.mdAll,
        border: Border.all(color: c.outlineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(_source.displayName, style: context.type.titleSmall)),
            Semantics(
              label: l10n.settingsStatusSemantics(connectionStatusLabel(l10n, status)),
              excludeSemantics: true,
              child: Container(
                key: ValueKey('settings.source.${_source.id}.status'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: context.radii.xsAll,
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  connecting ? l10n.settingsStatusConnecting : connectionStatusLabel(l10n, status),
                  style: context.type.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
          if (auth.isConnected && auth.accountName != null) ...[
            const SizedBox(height: 6),
            Text(l10n.settingsAccount(auth.accountName!), style: context.type.bodySmall),
          ],
          if (auth.isConnected && auth.grantedScopes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(l10n.settingsScopes(auth.grantedScopes.join(', ')), style: context.type.caption),
          ],
          if (status == SourceConnectionStatus.expired) ...[
            const SizedBox(height: 6),
            Text(l10n.settingsExpiredHint(_source.displayName), style: context.type.bodySmall.copyWith(color: c.warning)),
          ],
          if (status == SourceConnectionStatus.error && auth.error != null) ...[
            const SizedBox(height: 6),
            Text(l10n.settingsErrorDetail(auth.error!), style: context.type.bodySmall.copyWith(color: c.danger)),
          ],
          if (status == SourceConnectionStatus.credentialsMissing) ...[
            const SizedBox(height: 6),
            Text(l10n.settingsCredentialsMissingHint(_source.displayName), style: context.type.bodySmall),
          ],
          const SizedBox(height: 12),
          _Bullets(icon: Icons.check_rounded, color: c.success, items: abilities),
          _Bullets(icon: Icons.remove_rounded, color: c.textTertiary, items: limits),
          if (_source.limitationsNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_source.limitationsNote, style: context.type.bodySmall),
          ],
          if (connecting) ...[
            const SizedBox(height: 12),
            Row(children: [
              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.settingsConnectingHint, style: context.type.bodySmall)),
            ]),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (oauth && cred.configured && connecting)
              FermataButton(
                key: ValueKey('settings.source.${_source.id}.cancel'),
                label: l10n.actionCancel,
                variant: FermataButtonVariant.secondary,
                onPressed: _cancel,
              )
            else if (oauth && cred.configured && auth.isConnected)
              FermataButton(
                key: ValueKey('settings.source.${_source.id}.disconnect'),
                label: l10n.settingsDisconnect,
                variant: FermataButtonVariant.secondary,
                onPressed: _disconnect,
              )
            else if (oauth && cred.configured)
              FermataButton(
                key: ValueKey('settings.source.${_source.id}.connect'),
                label: status == SourceConnectionStatus.expired || status == SourceConnectionStatus.error
                    ? l10n.settingsReconnect
                    : l10n.settingsConnect,
                icon: Icons.login_rounded,
                onPressed: _connect,
              ),
            if (cred.configured && needsCredentials && !_editCredentials)
              FermataButton(
                key: ValueKey('settings.source.${_source.id}.editCredentials'),
                label: l10n.settingsCredOverride,
                variant: FermataButtonVariant.ghost,
                onPressed: () => setState(() => _editCredentials = true),
              ),
            if (_source.termsUrl != null)
              FermataButton(
                label: l10n.settingsTerms,
                icon: Icons.open_in_new_rounded,
                variant: FermataButtonVariant.ghost,
                onPressed: () => ref.read(externalLinkLauncherProvider)(_source.termsUrl!),
              ),
          ]),
          if (showEditor)
            CredentialsEditor(
              source: _source,
              onDone: cred.configured ? () => setState(() => _editCredentials = false) : null,
            ),
        ],
      ),
    );
  }
}

/// Emits whenever developer credentials change (any source).
final _credentialChangesProvider = StreamProvider.autoDispose<String>((ref) => ref.watch(credentialsStoreProvider).changes);

class _Bullets extends StatelessWidget {
  const _Bullets({required this.icon, required this.color, required this.items});

  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: context.type.bodySmall)),
            ]),
          ),
      ],
    );
  }
}
