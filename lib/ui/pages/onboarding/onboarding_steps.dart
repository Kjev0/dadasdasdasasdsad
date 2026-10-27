import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/contracts/platform.dart';
import '../../../core/errors.dart';
import '../../../core/models/auth.dart';
import '../../../core/sources/source_ids.dart';
import '../../design/context_ext.dart';
import '../../widgets/brand/fermata_mark.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../settings/settings_hooks.dart';
import '../settings/widgets/setting_tiles.dart';
import 'music_folders.dart';

final _log = Logger('ui.onboarding');

/// Scrollable, centred column used by every onboarding step.
class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.title, this.body, required this.children, this.icon, this.leading});

  final String title;
  final String? body;
  final IconData? icon;

  /// Shown instead of [icon] (the logo on the welcome step).
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[
                  Align(alignment: AlignmentDirectional.centerStart, child: leading),
                  const SizedBox(height: 24),
                ] else if (icon != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: c.surfaceHigh, shape: BoxShape.circle),
                      child: Icon(icon, color: c.accentText),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Semantics(header: true, child: Text(title, style: context.type.headline)),
                if (body != null) ...[
                  const SizedBox(height: 10),
                  Text(body!, style: context.type.body.copyWith(color: c.textSecondary)),
                ],
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: context.colors.accentText),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: context.type.body)),
      ]),
    );
  }
}

/// Step 1: welcome and value proposition.
class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _StepFrame(
      leading: const FermataLogo(markSize: 48),
      title: l10n.onboardingWelcomeTitle,
      body: l10n.onboardingWelcomeBody,
      children: [
        _Point(icon: Icons.folder_outlined, text: l10n.onboardingPointFiles),
        _Point(icon: Icons.hub_outlined, text: l10n.onboardingPointServices),
        _Point(icon: Icons.music_note_outlined, text: l10n.onboardingPointBackground),
        _Point(icon: Icons.shield_outlined, text: l10n.onboardingPointPrivacy),
      ],
    );
  }
}

/// Step 2: add music folders (Android asks for the audio permission first,
/// with a rationale).
class OnboardingMusic extends ConsumerStatefulWidget {
  const OnboardingMusic({super.key});

  @override
  ConsumerState<OnboardingMusic> createState() => _OnboardingMusicState();
}

class _OnboardingMusicState extends ConsumerState<OnboardingMusic> {
  final _added = <String>[];
  bool? _permitted;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final helper = ref.read(androidSystemProvider);
    if (helper.isSupported) {
      helper.audioLibraryPermitted().then((v) {
        if (mounted) setState(() => _permitted = v);
      }, onError: (Object _) {});
    }
  }

  Future<void> _requestPermission() async {
    final granted = await ref.read(androidSystemProvider).requestAudioLibraryPermission();
    if (mounted) setState(() => _permitted = granted);
  }

  Future<void> _add(String path) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final library = ref.read(localLibraryProvider);
      await library.addFolder(path);
      unawaited(library.scan(folder: path).drain<void>().catchError((Object e, StackTrace st) {
        _log.warning('Scanning $path failed', e, st);
      }));
      if (mounted) setState(() => _added.add(path));
    } catch (e) {
      if (mounted) {
        showFermataToast(context, e is StorageException ? l10n.onboardingFolderMissing : l10n.errorGeneric, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final path = await ref.read(fileDialogsProvider).pickDirectory(title: context.l10n.onboardingChooseFolder);
    if (path != null && !_added.contains(path)) await _add(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final helper = ref.watch(androidSystemProvider);
    final suggestion = ref.watch(suggestedMusicFolderProvider);
    final needsPermission = helper.isSupported && _permitted != true;
    return _StepFrame(
      icon: Icons.library_music_outlined,
      title: l10n.onboardingMusicTitle,
      body: l10n.onboardingMusicBody,
      children: [
        if (needsPermission) ...[
          SettingNote(text: l10n.onboardingAudioPermissionRationale, icon: Icons.lock_outline_rounded),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FermataButton(
              key: const ValueKey('onboarding.audioPermission'),
              label: l10n.onboardingAllowAudio,
              onPressed: _requestPermission,
            ),
          ),
          if (_permitted == false) ...[
            const SizedBox(height: 8),
            Text(l10n.onboardingAudioDenied, style: context.type.bodySmall),
            TextButton(onPressed: helper.openAppSettings, child: Text(l10n.settingsOpenSystemSettings)),
          ],
        ] else ...[
          if (suggestion != null && !_added.contains(suggestion))
            Container(
              key: const ValueKey('onboarding.suggestedFolder'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: context.radii.mdAll,
                border: Border.all(color: c.outlineSubtle),
              ),
              child: Row(children: [
                Icon(Icons.folder_special_outlined, color: c.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.onboardingSuggestedFolder, style: context.type.titleSmall),
                    Text(suggestion, style: context.type.bodySmall),
                  ]),
                ),
                FermataButton(
                  key: const ValueKey('onboarding.addSuggested'),
                  label: l10n.onboardingAdd,
                  busy: _busy,
                  onPressed: () => _add(suggestion),
                ),
              ]),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FermataButton(
              key: const ValueKey('onboarding.chooseFolder'),
              label: l10n.onboardingChooseFolder,
              icon: Icons.create_new_folder_outlined,
              variant: FermataButtonVariant.secondary,
              onPressed: _busy ? null : _pick,
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final f in _added)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, size: 18, color: c.success),
              const SizedBox(width: 8),
              Expanded(child: Text(f, style: context.type.bodySmall)),
            ]),
          ),
        if (_added.isNotEmpty) Text(l10n.onboardingScanning, style: context.type.caption),
        const SizedBox(height: 8),
        Text(l10n.onboardingMusicLater, style: context.type.caption),
      ],
    );
  }
}

/// Step 3: connect services (optional; SoundCloud first and highlighted).
class OnboardingServices extends ConsumerWidget {
  const OnboardingServices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(sourcesRevisionProvider);
    final all = ref.watch(sourceRegistryProvider).all;
    final oauth = [for (final s in all) if (s.supports(SourceCapability.oauth)) s]
      ..sort((a, b) => (a.id == SourceIds.soundcloud ? 0 : 1).compareTo(b.id == SourceIds.soundcloud ? 0 : 1));
    final open = [for (final s in all) if (!s.supports(SourceCapability.oauth) && s.id != SourceIds.local) s.displayName];
    return _StepFrame(
      icon: Icons.hub_outlined,
      title: l10n.onboardingServicesTitle,
      body: l10n.onboardingServicesBody,
      children: [
        for (final s in oauth) _ServiceTile(source: s, highlighted: s.id == SourceIds.soundcloud),
        if (open.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.onboardingNoAccountNeeded(open.join(', ')), style: context.type.bodySmall),
        ],
        const SizedBox(height: 8),
        Text(l10n.onboardingServicesLater, style: context.type.caption),
      ],
    );
  }
}

class _ServiceTile extends ConsumerStatefulWidget {
  const _ServiceTile({required this.source, required this.highlighted});

  final MusicSource source;
  final bool highlighted;

  @override
  ConsumerState<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends ConsumerState<_ServiceTile> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      await widget.source.connect();
    } catch (e) {
      if (mounted) {
        final msg = errorMessageFor(context.l10n, e);
        if (msg != null) showFermataToast(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final s = widget.source;
    return StreamBuilder<SourceAuthState>(
      stream: s.authStateChanges,
      initialData: s.authState,
      builder: (context, snap) {
        final auth = snap.data ?? s.authState;
        final configured = s.credentialStatus.configured;
        return Container(
          key: ValueKey('onboarding.service.${s.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.highlighted ? c.accent.withValues(alpha: 0.08) : c.surface,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: widget.highlighted ? c.accent.withValues(alpha: 0.6) : c.outlineSubtle),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(s.displayName, style: context.type.titleSmall)),
                  if (widget.highlighted) ...[
                    const SizedBox(width: 8),
                    Text(l10n.onboardingRecommended, style: context.type.caption.copyWith(color: c.accentText)),
                  ],
                ]),
                Text(
                  auth.isConnected
                      ? l10n.onboardingConnectedAs(auth.accountName ?? s.displayName)
                      : configured
                          ? l10n.onboardingServiceHint
                          : l10n.onboardingNeedsCredentials,
                  style: context.type.bodySmall,
                ),
              ]),
            ),
            const SizedBox(width: 12),
            if (auth.isConnected)
              Icon(Icons.check_circle_rounded, color: c.success, semanticLabel: l10n.settingsStatusConnected)
            else if (configured)
              FermataButton(
                key: ValueKey('onboarding.service.${s.id}.connect'),
                label: l10n.settingsConnect,
                busy: _connecting,
                variant: widget.highlighted ? FermataButtonVariant.primary : FermataButtonVariant.secondary,
                onPressed: _connect,
              ),
          ]),
        );
      },
    );
  }
}

/// Step 4: background playback and notifications.
class OnboardingBackground extends ConsumerStatefulWidget {
  const OnboardingBackground({super.key});

  @override
  ConsumerState<OnboardingBackground> createState() => _OnboardingBackgroundState();
}

class _OnboardingBackgroundState extends ConsumerState<OnboardingBackground> {
  bool? _notifications;

  @override
  void initState() {
    super.initState();
    final helper = ref.read(androidSystemProvider);
    if (helper.isSupported) {
      helper.notificationsPermitted().then((v) {
        if (mounted) setState(() => _notifications = v);
      }, onError: (Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final platform = ref.watch(platformInfoProvider);
    final helper = ref.watch(androidSystemProvider);
    if (platform.isAndroid) {
      return _StepFrame(
        icon: Icons.notifications_none_rounded,
        title: l10n.onboardingBackgroundTitle,
        body: l10n.onboardingBackgroundAndroid,
        children: [
          if (helper.isSupported) ...[
            SettingNote(text: l10n.onboardingNotificationRationale),
            if (_notifications == true)
              Text(l10n.onboardingNotificationsAllowed, style: context.type.bodySmall)
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FermataButton(
                  key: const ValueKey('onboarding.notifications'),
                  label: l10n.onboardingAllowNotifications,
                  onPressed: () async {
                    final granted = await helper.requestNotificationPermission();
                    if (mounted) setState(() => _notifications = granted);
                  },
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(l10n.onboardingBatteryNote, style: context.type.caption),
        ],
      );
    }
    final lifecycle = ref.watch(appLifecycleProvider);
    final close = ref.watch(settingsProvider.select((s) => s.desktop.closeBehavior));
    return _StepFrame(
      icon: Icons.music_note_outlined,
      title: l10n.onboardingBackgroundTitle,
      body: lifecycle.trayAvailable ? l10n.onboardingBackgroundTray : l10n.onboardingBackgroundNoTray,
      children: [
        SettingsGroup(children: [
          SettingChoice<CloseBehavior>(
            key: const ValueKey('onboarding.closeBehavior'),
            title: l10n.settingsCloseBehavior,
            value: close,
            forceDropdown: true,
            options: [
              SettingOption(CloseBehavior.minimizeToTray, lifecycle.trayAvailable ? l10n.settingsCloseToTray : l10n.settingsCloseMinimize),
              SettingOption(CloseBehavior.ask, l10n.settingsCloseAsk),
              SettingOption(CloseBehavior.exit, l10n.settingsCloseQuit),
            ],
            onChanged: (v) => ref.read(settingsStoreProvider).update((s) => s.copyWith(desktop: s.desktop.copyWith(closeBehavior: v))),
          ),
        ]),
        Text(l10n.onboardingMediaKeys, style: context.type.bodySmall),
      ],
    );
  }
}
