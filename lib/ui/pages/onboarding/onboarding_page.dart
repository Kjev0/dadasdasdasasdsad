import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/brand/fermata_mark.dart';
import '../../widgets/controls/fermata_button.dart';
import 'onboarding_steps.dart';

final _log = Logger('ui.onboarding');

/// Marks onboarding as completed and opens Home.
Future<void> completeOnboarding(BuildContext context, WidgetRef ref) async {
  await ref.read(settingsStoreProvider).update((s) => s.copyWith(onboardingCompleted: true));
  if (context.mounted) context.go(AppRoutes.home);
}

/// First-run introduction: welcome, add music, connect services (optional),
/// background playback & notifications. Every step can be skipped.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _count = 4;
  final _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _go(int page) async {
    final d = ref.read(effectiveVisualsProvider).duration(const Duration(milliseconds: 360));
    setState(() => _page = page);
    if (d == Duration.zero) {
      _pages.jumpToPage(page);
    } else {
      await _pages.animateToPage(page, duration: d, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await completeOnboarding(context, ref);
    } catch (e, st) {
      _log.warning('Completing onboarding failed', e, st);
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final last = _page == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                const FermataMark(size: 22),
                const Spacer(),
                if (!last)
                  TextButton(
                    key: const ValueKey('onboarding.skip'),
                    onPressed: _finishing ? null : _finish,
                    child: Text(l10n.onboardingSkip),
                  ),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  OnboardingWelcome(),
                  OnboardingMusic(),
                  OnboardingServices(),
                  OnboardingBackground(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                if (_page > 0)
                  FermataButton(
                    key: const ValueKey('onboarding.back'),
                    label: l10n.onboardingBack,
                    variant: FermataButtonVariant.ghost,
                    onPressed: () => _go(_page - 1),
                  )
                else
                  const SizedBox(width: 64),
                Expanded(
                  child: Semantics(
                    label: l10n.onboardingStepOf(_page + 1, _count),
                    excludeSemantics: true,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: ref.watch(effectiveVisualsProvider).duration(const Duration(milliseconds: 220)),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? c.accent : c.outline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ]),
                  ),
                ),
                FermataButton(
                  key: ValueKey(last ? 'onboarding.finish' : 'onboarding.next'),
                  label: last ? l10n.onboardingFinish : (_page == 0 ? l10n.onboardingGetStarted : l10n.onboardingNext),
                  busy: _finishing,
                  onPressed: last ? _finish : () => _go(_page + 1),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
