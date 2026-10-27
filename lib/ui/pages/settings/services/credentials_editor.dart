import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/auth.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../core/models/auth.dart';
import '../../../../core/sources/source_ids.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../actions/link_launcher.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/feedback/toast.dart';

/// Credential fields a built-in provider uses (shown when the user wants to
/// override already-configured credentials; `CredentialStatus.missing` only
/// lists what is missing).
const _knownFields = <String, List<String>>{
  SourceIds.soundcloud: ['clientId', 'clientSecret'],
  SourceIds.spotify: ['clientId'],
  SourceIds.youtube: ['apiKey', 'clientId', 'clientSecret'],
  SourceIds.jamendo: ['clientId'],
  SourceIds.audius: ['apiKey'],
};

/// Fields to show in the editor for [source].
List<String> credentialFieldsFor(MusicSource source, SourceCredentials? existing) {
  final fields = <String>[...source.credentialStatus.missing];
  for (final f in _knownFields[source.id] ?? const <String>[]) {
    if (!fields.contains(f)) fields.add(f);
  }
  if (existing != null) {
    if (existing.clientId != null && !fields.contains('clientId')) fields.add('clientId');
    if (existing.clientSecret != null && !fields.contains('clientSecret')) fields.add('clientSecret');
    if (existing.apiKey != null && !fields.contains('apiKey')) fields.add('apiKey');
  }
  if (fields.isEmpty) fields.add(source.supports(SourceCapability.oauth) ? 'clientId' : 'apiKey');
  return fields;
}

String credentialFieldLabel(AppLocalizations l10n, String field) => switch (field) {
      'clientId' => l10n.settingsCredClientId,
      'clientSecret' => l10n.settingsCredClientSecret,
      'apiKey' => l10n.settingsCredApiKey,
      'redirectUri' => l10n.settingsCredRedirectUri,
      _ => field,
    };

String credentialOriginLabel(AppLocalizations l10n, CredentialOrigin origin, String configPath) => switch (origin) {
      CredentialOrigin.none => l10n.settingsCredOriginNone,
      CredentialOrigin.buildTime => l10n.settingsCredOriginBuild,
      CredentialOrigin.configFile => l10n.settingsCredOriginFile(configPath),
      CredentialOrigin.userEntered => l10n.settingsCredOriginUser,
    };

/// Redirect URIs a developer must register for an OAuth source: the
/// desktop loopback URI and the Android deep link (or the user's override).
List<(String label, String uri)> redirectUrisFor(AppLocalizations l10n, OAuthClient oauth, String sourceId, String? overrideUri) {
  OAuthConfig config(RedirectStrategy strategy) => OAuthConfig(
        sourceId: sourceId,
        authorizeEndpoint: Uri(),
        tokenEndpoint: Uri(),
        clientId: '',
        scopes: const [],
        redirectStrategy: strategy,
        redirectUriOverride: overrideUri,
      );
  if (overrideUri != null && overrideUri.isNotEmpty) return [(l10n.settingsCredRedirectCustom, overrideUri)];
  return [
    (l10n.settingsCredRedirectDesktop, oauth.redirectUriFor(config(RedirectStrategy.loopback))),
    if (sourceId != SourceIds.youtube) (l10n.settingsCredRedirectAndroid, oauth.redirectUriFor(config(RedirectStrategy.customScheme))),
  ];
}

/// "Developer credentials" editor for one source. Values are stored with
/// `CredentialsStore.setUserCredentials` (secure storage). Never asks for
/// account passwords — only app registration values.
class CredentialsEditor extends ConsumerStatefulWidget {
  const CredentialsEditor({super.key, required this.source, this.onDone});

  final MusicSource source;
  final VoidCallback? onDone;

  @override
  ConsumerState<CredentialsEditor> createState() => _CredentialsEditorState();
}

class _CredentialsEditorState extends ConsumerState<CredentialsEditor> {
  /// Only values the user entered are shown again; build-time or config-file
  /// secrets never appear in the UI.
  late final SourceCredentials? _existing = ref.read(credentialsStoreProvider).originOf(widget.source.id) == CredentialOrigin.userEntered
      ? ref.read(credentialsStoreProvider).get(widget.source.id)
      : null;
  late final List<String> _fields = credentialFieldsFor(widget.source, _existing);
  late final Map<String, TextEditingController> _controllers = {
    for (final f in [..._fields, if (_isOAuth) 'redirectUri']) f: TextEditingController(text: _valueOf(_existing, f)),
  };
  final _obscured = <String>{'clientSecret', 'apiKey'};
  bool _saving = false;
  String? _error;

  bool get _isOAuth => widget.source.supports(SourceCapability.oauth);

  static String _valueOf(SourceCredentials? c, String field) => switch (field) {
        'clientId' => c?.clientId ?? '',
        'clientSecret' => c?.clientSecret ?? '',
        'apiKey' => c?.apiKey ?? '',
        'redirectUri' => c?.redirectUri ?? '',
        _ => '',
      };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _value(String f) {
    final v = _controllers[f]?.text.trim();
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final required = widget.source.credentialStatus.missing.isNotEmpty ? widget.source.credentialStatus.missing : [_fields.first];
    final empty = [for (final f in required) if (_value(f) == null) credentialFieldLabel(l10n, f)];
    if (empty.isNotEmpty) {
      setState(() => _error = l10n.settingsCredRequired(empty.join(', ')));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(credentialsStoreProvider).setUserCredentials(
            widget.source.id,
            SourceCredentials(
              clientId: _value('clientId'),
              clientSecret: _value('clientSecret'),
              apiKey: _value('apiKey'),
              redirectUri: _value('redirectUri'),
            ),
          );
      if (!mounted) return;
      showFermataToast(context, l10n.settingsCredSaved(widget.source.displayName), icon: Icons.check_rounded);
      widget.onDone?.call();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.settingsCredSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    await ref.read(credentialsStoreProvider).setUserCredentials(widget.source.id, null);
    if (!mounted) return;
    showFermataToast(context, context.l10n.settingsCredRemoved, icon: Icons.check_rounded);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final store = ref.watch(credentialsStoreProvider);
    final status = widget.source.credentialStatus;
    final origin = store.originOf(widget.source.id);
    final redirects =
        _isOAuth ? redirectUrisFor(l10n, ref.watch(oauthClientProvider), widget.source.id, _existing?.redirectUri) : const <(String, String)>[];

    return Container(
      key: ValueKey('settings.credentials.${widget.source.id}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceHigh.withValues(alpha: 0.5), borderRadius: context.radii.smAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsCredTitle, style: context.type.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.settingsCredIntro(widget.source.displayName), style: context.type.bodySmall),
          const SizedBox(height: 4),
          Text(l10n.settingsCredOrigin(credentialOriginLabel(l10n, origin, store.configFilePath)),
              style: context.type.caption.copyWith(color: c.textSecondary)),
          if (status.helpUrl != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l10n.settingsCredRegister),
                onPressed: () => ref.read(externalLinkLauncherProvider)(status.helpUrl!),
              ),
            ),
          if (redirects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.settingsCredRedirects, style: context.type.label),
            for (final (label, uri) in redirects)
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: context.type.caption),
                    SelectableText(uri, style: context.type.bodySmall.copyWith(color: c.textPrimary)),
                  ]),
                ),
                IconButton(
                  tooltip: l10n.settingsCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: uri));
                    if (context.mounted) showFermataToast(context, l10n.settingsCopied, icon: Icons.check_rounded);
                  },
                ),
              ]),
          ],
          const SizedBox(height: 12),
          for (final f in _controllers.keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: ValueKey('settings.cred.${widget.source.id}.$f'),
                controller: _controllers[f],
                obscureText: _obscured.contains(f),
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: credentialFieldLabel(l10n, f) + (f == 'redirectUri' ? ' (${l10n.settingsCredOptional})' : ''),
                  suffixIcon: f == 'clientSecret' || f == 'apiKey'
                      ? IconButton(
                          tooltip: _obscured.contains(f) ? l10n.settingsCredShow : l10n.settingsCredHide,
                          icon: Icon(_obscured.contains(f) ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _obscured.contains(f) ? _obscured.remove(f) : _obscured.add(f)),
                        )
                      : null,
                ),
              ),
            ),
          if (_error != null) Text(_error!, style: context.type.bodySmall.copyWith(color: c.danger)),
          Text(l10n.settingsCredNoPasswords, style: context.type.caption),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FermataButton(
              key: ValueKey('settings.cred.${widget.source.id}.save'),
              label: l10n.actionSave,
              busy: _saving,
              onPressed: _save,
            ),
            if (origin == CredentialOrigin.userEntered)
              FermataButton(label: l10n.settingsCredRemove, variant: FermataButtonVariant.secondary, onPressed: _remove),
            if (widget.onDone != null && status.configured)
              FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: widget.onDone),
          ]),
        ],
      ),
    );
  }
}
