# Fermata UI foundation

Design system, app shell, router, player UI, Liquid Glass and the shared
widgets every page uses. Import the barrels:

```dart
import 'package:fermata/ui/design/design.dart';   // tokens, theme, context accessors
import 'package:fermata/ui/widgets/widgets.dart'; // shared widgets + TrackActions + AppRoutes
```

UI code talks to services **only** through `lib/app/providers.dart`.

## Tokens (`ThemeExtension`s, built by `buildFermataTheme`)

Read them with `context.colors`, `context.type`, `context.radii`,
`context.spacing`, `context.motion`, `context.l10n` (`context_ext.dart`).

### `FermataColors` (`fermata_colors.dart`)
| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0C0C0E` | `#F6F4EF` | app background |
| `surface` | `#141417` | `#FFFFFF` | cards, chrome (glass off) |
| `surfaceRaised` | `#1B1B20` | `#FBFAF7` | menus, dialogs, sheets |
| `surfaceHigh` | `#24242B` | `#EFEDE7` | inputs, chips, hover fills |
| `outline` / `outlineSubtle` | `#2E2E36` / `#232329` | `#DEDAD2` / `#E9E6DF` | borders, dividers |
| `textPrimary` | `#F3F1EC` | `#17161A` | body text |
| `textSecondary` | `#A9A7A1` | `#57544F` | secondary text, hints |
| `textTertiary` | `#6E6C68` | `#8A867F` | captions/disabled on bg/surface/surfaceRaised only (never on `surfaceHigh`) |
| `accent` / `accentHover` / `onAccent` | gold `#E9B44C` / `#F2C25E` / `#17130A` | `#8C6210` / derived / `#FFFFFF` | fills, active state |
| `accentText` | accent ≥ 4.5:1 (7:1 high contrast) on every surface | | accent-coloured text & small icons |
| `success` / `warning` / `danger` | `#6BCB8B` / `#E9A23B` / `#EF6B5F` | darkened to ≥ 4.5:1 | status |
| `scrim`, `shadow` | | | modal barrier, soft shadow (floating surfaces only) |

Accents (`AccentChoice`): gold, coral `#FF8A6B`, mint `#6BD6B0`, ice
`#8CC8FF`, mono (= text colour). Light-mode variants are derived with
`Contrast.ensure` to ≥ 4.5:1 on all light surfaces. High contrast raises
text, outline and accent-text contrast. All ratios are unit-tested
(`test/ui/foundation/theme_tokens_test.dart`).

### Type (`FermataTypography`, Manrope; tabular figures via `FermataTypography.tabular`)
display 40/44 w700 −1.0 · headline 28/34 w700 −0.4 · title 20/26 w600 ·
titleSmall 16/22 w600 · body 15/22 w500 · bodySmall 13/18 w500 · label
13/16 w600 +0.2 · caption 12/16 w500. Mapped to `TextTheme`
(display*/headline*/title*/body*/label*). Use theme styles (not literal font
sizes) so text scaling applies.

### Radii, spacing, density, motion
* `FermataRadii`: xs 6 (badges) · sm 10 (buttons, inputs, rows) · md 14
  (cards, menus) · lg 20 (dialogs, large artwork) · xl 28 (sheets).
* `FermataSpacing`: grid `s4 … s72` (4, 8, 12, 16, 20, 24, 32, 40, 56, 72);
  density metrics `rowHeight` (56/48), `controlHeight`, `gutter`;
  `context.rowExtent` = row height grown with the text scale (use for
  fixed-extent lists).
* `FermataMotion`: micro 120 ms, standard 220 ms, emphasis 360 ms,
  `Curves.easeOutCubic`; durations are already scaled by
  `EffectiveVisuals.duration()` (reduced = half, off = zero). For widgets
  that read Riverpod, use `ref.watch(effectiveVisualsProvider).duration(base)`.
  No continuous animation unless something is playing and `visuals.animate`.
* Icons: rounded Material icons only (`Icons.*_rounded`). No emoji, no
  decorative gradients (gradients only from artwork colours).

### Theme & app
`buildFermataTheme({brightness, accent, highContrast, density, textScale,
largerTargets, visuals})`. `FermataApp` builds light/dark/high-contrast
themes from settings, sets the locale (`localeProvider`), combines the
system text scale with `accessibility.textScale` in `MediaQuery.textScaler`
(the theme's own `textScale` stays 1.0), syncs `systemReduceMotionProvider`
from `MediaQuery.disableAnimations`, installs keyboard shortcuts and
registers the "Close Fermata?" dialog as
`AppLifecycleController.closeDecisionDelegate`. Fixed-height chrome
(player bar, mini-player, bottom nav) clamps text scaling to 1.2–1.3×;
everything else scales fully.

## Liquid Glass (`widgets/glass/`, default OFF)
* `GlassSurface(child, borderRadius, edges, raised, floating, mode?, intensity?)`
  — used by sidebar, rail, player bar, mini-player, bottom nav and sheets
  (`showFermataSheet`). Modes (`GlassMode.of(visuals)`): **solid** (glass
  off), **translucent** (glass on, blur disabled by performance/battery
  modes; tinted fill, no `BackdropFilter`), **blurred** (`BackdropFilter`
  σ 18–28 by intensity, fill α 0.78→0.55, hairline border, top highlight,
  diagonal sheen; clipped to the radius). Mode changes cross-fade
  (`AnimatedSwitcher`, emphasis duration); the child is never rebuilt.
* `GlassSpec.resolve` raises the fill alpha until primary **and** secondary
  text are ≥ 4.5:1 over the worst-case ambient backdrop (tested).
* `AmbientBackdrop(artworkUrl)` — painted by the shell behind the chrome:
  heavily blurred artwork (blur allowed) or a cheap gradient from the
  artwork palette (`ArtworkPalette`, ≤ 32×32 decode), always under a
  `bg` scrim (that scrim is what makes the contrast guarantee hold).
* `GlassPreview(mode?, intensity?)` — mini sidebar + player mock for
  Settings → Liquid Glass; reacts to settings live; pass `intensity` while
  a slider is dragged. Never call it "Apple Liquid Glass".

## Shell & routing
* `lib/app/router.dart`: `routerProvider`, `buildRouter(Ref)`,
  `initialLocationProvider` (tests), `onboardingRedirect`. `ShellRoute`
  (`AppShell`) for content pages; `/now-playing` (slide-up, full screen) and
  `/onboarding` on the root navigator. `/` → `/onboarding` until
  `onboardingCompleted`, else `/home`.
* Build locations with `AppRoutes` (`actions/routes.dart`):
  `AppRoutes.playlist(id)`, `.artist(sourceId, artistId)` (local: artist
  name), `.album(sourceId, albumId)` (local: album title; remote tracks:
  `extra['albumId']` or `extra['<source>.albumId']`), `.library(tab:)`,
  `.settingsSection(id)`, `.importSession(id)`, `.nowPlayingView('lyrics'|'queue')`.
* **Settings section ids** (`SettingsSections`): appearance, glass,
  playback, audioQuality, downloads, storage, performance, savers, services,
  import, notifications, background, desktop, startup, shortcuts, privacy,
  language, accessibility, updates, about — `SettingsPage(section:)` must
  accept these.
* Layouts (`LayoutSize`): compact < 600 (bottom `NavigationBar` + docked
  `MiniPlayer`), medium 600–1023 (`FermataNavRail` + `PlayerBar`), expanded
  ≥ 1024 (248 px `Sidebar` with playlists + 88 px `PlayerBar`). The routed
  page keeps its state across breakpoints. Navigation never calls the
  playback controller.
* Pages should use a `Scaffold` (default background `bg`); the shell's own
  scaffold is transparent so the ambient backdrop shows behind glass chrome.

## Player UI (`lib/ui/player/`)
`PlayerBar`, `MiniPlayer`, `NowPlayingPage(initialPanel)`, `QueuePage` /
`QueueList`, `SeekBar` (drag preview, tap, ←/→ 5 s, Home/End, slider
semantics), `TransportControls` (+ individual buttons), `VolumeControl`,
`OutputDeviceButton`, `SpeedButton`, `SleepTimerButton`, `LyricsView`
(synced highlight + auto-scroll + tap to seek; plain fallback; "Lyrics:
LRCLIB"), `MiniModeView` + `miniModeProvider` (desktop 380×132 window,
optional always-on-top), `playbackFailureProvider` (error banner + "skipped"
toast), `lyricsProvider`, `downloadEligibilityProvider`.
Sleep timer: minutes → `setSleepTimer(d)`, end of track →
`setSleepTimer(null, endOfTrack: true)`, off → `setSleepTimer(null)`.

## Keyboard shortcuts & command palette
* `FermataShortcuts` (in `MaterialApp.builder`) maps
  `settings.shortcuts.bindings` → `Shortcuts`/`Actions`. Bindings without
  Ctrl/Alt/Meta (e.g. Space) and text-editing combos never fire while a text
  field is focused.
* `CommandRegistry` (`actions/command_registry.dart`): `commands(l10n)`,
  `runShortcut(id, ctx, l10n)`, `labelFor(l10n, actionId)`,
  `sectionLabel(l10n, section)`, `shortcutActions`, `allBindableActions`.
  `ShortcutBinding` parses/serializes/formats accelerators
  (`ctrl+alt+space` ↔ `Ctrl+Alt+Space`) and records them from key events
  (`fromKeyEvent`) — use it for the settings shortcut recorder.
* `showCommandPalette(context)` / Ctrl+K: fuzzy search (`fuzzy.dart`) over
  destinations, player commands, settings sections, playlists and library
  tracks (`TrackRepository.query`).

## Shared widgets (`lib/ui/widgets/`)
| Widget | Notes |
|---|---|
| `ArtworkImage(uri, size, borderRadius, circle)` | http/file; decode size from `EffectiveVisuals.artworkPixels`; fade-in; fermata-mark placeholder. Resolver overridable via `artworkImageResolverProvider`. |
| `TrackTile(track, playContext, index, showArtwork, showAlbum, showSource, selectionMode, …)` | badges, now-playing glyph, like, duration; right-click / ⋯ menu, long-press sheet. Download entries only when the provider policy allows **and** the manager says eligible. External-only tracks open on the provider; unavailable tracks are dimmed and explain why. |
| `TrackListView(tracks, origin, originLabel, header, footer, selection, extraBulkActions, …)` | virtualized (`SliverFixedExtentList`), long-press → selection mode + `TrackSelectionBar` (play, queue, add to playlist, download eligible). `TrackSelectionController` can be shared. |
| `MediaCard`, `ShelfRow` | cards with hover quick-play; shelf with paging arrows on ≥ 600 dp. |
| `SectionHeader`, `EmptyState`, `ErrorState(error, onRetry)` | `ErrorState` maps `FermataException` → localized text (`errorMessageFor`). |
| `Skeleton`, `SkeletonShimmer`, `SkeletonTrackTile`, `SkeletonTrackList`, `SkeletonCard` | shimmer only when animations are allowed. |
| `SourceChip(sourceId)`, `AvailabilityBadge(kind)` / `.forTrack` | text only, never logos; kinds: userOwned, downloadable, streamOnly, unavailableOffline, preview, external, downloaded, unavailable. |
| `FermataButton(variant: primary/secondary/ghost/danger, busy)`, `SearchField`, `SegmentedTabs<T>` | |
| `ConfirmDialog.show(…, typedConfirmation:)`, `TextInputDialog.show`, `showFermataSheet`, `AddToPlaylistSheet.pick` | |
| `showFermataToast(context, message, icon:, isError:)` | floating snack bar. |
| `TrackActions(context, ref)` / `.fromContainer` | play / playNext / addToQueue (SoundCloud silo → "Start a new queue?" dialog on `UnsupportedSourceOperation('mix_queue')`), favorites, download / downloadAll / removeDownload (policy-guarded via `SourcePolicies`), addToPlaylist, openExternally, copyLink, goToArtist/Album — all with localized error toasts. |
| `userPlaylistsProvider`, `editablePlaylistsProvider` | refetch on `LibraryTopic.playlists`. |
| `availabilityReasonText`, `offlineRightsLabel`, `errorMessageFor`, `formatDuration`, `sourceDisplayName` | helpers. |

## Strings
`lib/l10n/fragments/shell_*.arb` (prefixes `nav*`, `shell*`, `palette*`,
`cmd*`) and `player_*.arb` (`player*`). Other areas must not reuse these
prefixes.

## Bootstrap wiring
```dart
runApp(ProviderScope(
  overrides: [
    ...serviceOverrides(services),
    // Optional: disk-cached artwork from the downloads module.
    artworkImageResolverProvider.overrideWithValue((uri) => switch (uri.scheme) {
          'http' || 'https' => CachedNetworkImageProvider(uri.toString(), cacheManager: artworkCache),
          _ => defaultArtworkResolver(uri),
        }),
    // Desktop: route mini mode through the lifecycle controller so window
    // bounds are not persisted while mini.
    if (desktopWindow != null) miniWindowControllerProvider.overrideWithValue(desktopWindow),
  ],
  child: const FermataApp(),
));
```
Without overrides, artwork uses `NetworkImage`/`FileImage` (memory cache)
and mini mode uses `window_manager` directly (desktop only; Android has no
mini mode). `window_manager` must be initialised by the platform module.

## Testing
Fake kit: `test/ui/fakes/` (`FakeKit`, `pumpFermata`, `pumpInApp`,
fixtures). See `test/ui/fakes/README.md`.

## Known limitations
* `FermataLogo` uses `assets/branding/logo_mark.svg` when bundled, else the
  painted mark.
* Artwork palette extraction needs the image to decode; network failures
  fall back to the accent-tint backdrop.
* The download "eligible" check in menus is asynchronous (one
  `checkEligibility` call when the menu opens).
