# Spec: UI foundation — design system, shell, player UI, glass
(`lib/ui/design/**`, `lib/ui/shell/**`, `lib/ui/player/**`, `lib/ui/widgets/**`, `lib/ui/actions/**`, `lib/app/app.dart`, `lib/app/router.dart`, `lib/l10n/fragments/shell_*.arb`, `lib/l10n/fragments/player_*.arb`, `test/ui/foundation/**`, `test/ui/fakes/**`, stub files under `lib/ui/pages/**` (see below))

The UI talks to services ONLY via `lib/app/providers.dart` (read it). Other
agents build the real services in parallel; for widget tests build a fake kit.

## Brand & design language (premium, minimalist, artwork-first)
* Name **Fermata**; logo = fermata mark (`assets/branding/logo_mark.svg`,
  `logo_full_dark.svg`, `logo_full_light.svg` — created by the branding agent;
  use `flutter_svg`; if a file is missing at test time, tests must not depend
  on it). Font **Manrope** (assets/fonts; the lead registers it in pubspec —
  use `fontFamily: 'Manrope'` and let it fall back gracefully).
* Dark (primary) tokens: bg `#0C0C0E`, surface `#141417`, surfaceRaised
  `#1B1B20`, surfaceHigh `#24242B`, outline `#2E2E36`, outlineSubtle `#232329`,
  textPrimary `#F3F1EC`, textSecondary `#A9A7A1`, textTertiary `#6E6C68`,
  accent (gold) `#E9B44C`, accentHover `#F2C25E`, onAccent `#17130A`,
  success `#6BCB8B`, warning `#E9A23B`, danger `#EF6B5F`.
  Light tokens: bg `#F6F4EF`, surface `#FFFFFF`, surfaceRaised `#FBFAF7`,
  surfaceHigh `#EFEDE7`, outline `#DEDAD2`, textPrimary `#17161A`,
  textSecondary `#57544F`, textTertiary `#8A867F`, accent `#8C6210`,
  onAccent `#FFFFFF`. Alternative accents (`AccentChoice`): coral `#FF8A6B`,
  mint `#6BD6B0`, ice `#8CC8FF`, mono (text color); derive light-mode variants
  with ≥ 4.5:1 contrast for text-on-surface uses. High-contrast mode raises
  text/outline contrast. Verify contrast in a unit test.
* Type scale (Manrope): display 40/44 w700 (-1.0), headline 28/34 w700
  (-0.4), title 20/26 w600, titleSmall 16/22 w600, body 15/22 w500, bodySmall
  13/18 w500, label 13/16 w600 (+0.2), caption 12/16 w500; tabular figures
  for times. Respect `accessibility.textScale` and system text scaling.
* Radii 6/10/14/20/28; spacing 4-pt grid (4, 8, 12, 16, 20, 24, 32, 40, 56,
  72); soft shadows only on floating surfaces. Rounded Material icons only
  (`Icons.*_rounded`) for consistency. No purple gradients, no emoji, no
  gratuitous gradients; gradients only from artwork colors.
* Motion: 120 ms micro, 220 ms standard, 360 ms emphasis; `Curves.easeOutCubic`;
  always scaled through `EffectiveVisuals.duration()` (reduced motion / perf
  modes / animations off). No continuous animations unless playing (e.g. a
  subtle equalizer glyph in the playing row may animate only when animate).
* Implement as `ThemeExtension`s (`FermataColors`, `FermataSpacing`,
  `FermataRadii`, `FermataMotion`) + `ThemeData` builder
  `buildFermataTheme({brightness, accent, highContrast, density, textScale})`.
  Document every token and component in `lib/ui/design/README.md`.

## Liquid Glass (optional; default OFF)
`GlassSurface` widget used by the sidebar, player bar, mini-player, bottom
nav, sheets: glass ON + blur allowed → `BackdropFilter` (sigma ≈ 18–28 ×
intensity) clipped by its radius, translucent fill (surface α 0.55–0.78 by
intensity), 1 px hairline border with a soft top highlight, subtle inner
gradient sheen; glass ON + blur disabled (perf/battery modes) → translucent
tinted fill without blur; glass OFF → solid surface. Behind glass surfaces,
the shell paints an ambient backdrop (heavily blurred current artwork /
accent tint) so the glass has something to refract; when blur is off the
backdrop is a cheap gradient from artwork colors. Must stay readable (text
contrast ≥ 4.5:1 over the glass fill — test it). Never claim it is Apple's
Liquid Glass. Animated cross-fade between modes (respecting motion prefs).
Provide `GlassPreview` widget (a mini mock of sidebar + player) that the
Settings page will embed as a live preview.

## Shell & navigation (`lib/ui/shell/`, `lib/app/router.dart`, `lib/app/app.dart`)
* `FermataApp` (`lib/app/app.dart`): `MaterialApp.router` with themes from
  settings (dark/light/system, accent, high contrast), `localeProvider`,
  `AppLocalizations.localizationsDelegates/supportedLocales`
  (`package:fermata/l10n/gen/app_localizations.dart`), updates
  `systemReduceMotionProvider` from `MediaQuery.disableAnimations`, applies
  textScale.
* go_router (`lib/app/router.dart`, `buildRouter(Ref/ProviderContainer)`):
  `ShellRoute` (or StatefulShellRoute) with routes:
  `/home`, `/search`, `/explore`, `/library?tab=`, `/playlists`,
  `/playlists/:id`, `/artist/:sourceId/:artistId`, `/album/:sourceId/:albumId`,
  `/downloads`, `/favorites`, `/history`, `/queue`, `/now-playing`,
  `/settings`, `/settings/:section`, `/import`, `/import/:sessionId`,
  `/onboarding`. Redirect `/` → `/onboarding` when `!onboardingCompleted`,
  else `/home`. Page classes (create minimal STUB files for pages you don't
  own, each containing the exact comment `// STUB(ui-pages)` or
  `// STUB(ui-settings)` so the owners replace them):
  `lib/ui/pages/home/home_page.dart` HomePage; `search/search_page.dart`
  SearchPage; `explore/explore_page.dart` ExplorePage;
  `library/library_page.dart` LibraryPage({String? tab});
  `playlists/playlists_page.dart` PlaylistsPage;
  `playlists/playlist_detail_page.dart` PlaylistDetailPage({required String playlistId});
  `artist/artist_page.dart` ArtistPage({required String sourceId, required String artistId});
  `album/album_page.dart` AlbumPage({required String sourceId, required String albumId});
  `downloads/downloads_page.dart` DownloadsPage; `favorites/favorites_page.dart`
  FavoritesPage; `history/history_page.dart` HistoryPage (all owned by
  ui-pages); `settings/settings_page.dart` SettingsPage({String? section});
  `import/import_page.dart` ImportPage; `import/import_review_page.dart`
  ImportReviewPage({required String sessionId}); `onboarding/onboarding_page.dart`
  OnboardingPage (owned by ui-settings). You own `lib/ui/player/queue_page.dart`
  QueuePage and `lib/ui/player/now_playing_page.dart` NowPlayingPage.
* Responsive layouts: compact < 600 dp → bottom `NavigationBar` (Home,
  Search, Explore, Library, Settings) with the mini-player docked above it;
  medium 600–1023 → navigation rail + bottom player bar; expanded ≥ 1024 →
  248 px sidebar (logo, Home, Search, Explore · Library, Playlists,
  Downloads, Favorites, History, Queue · user playlists list · Settings) +
  88 px bottom player bar. Window resizing must reflow without overflow
  (test at 360×640, 800×600, 1440×900).
* Navigation never touches playback (the controller is app-wide).

## Player UI (`lib/ui/player/`)
* Desktop player bar: artwork + title/artist (tap → now playing; artist →
  artist page) + like; transport (shuffle, previous, play/pause, next,
  repeat with one/all states) + seek bar with elapsed/remaining (tabular
  figures; drag preview; keyboard accessible); right cluster: lyrics,
  queue, output device menu (if `supportsOutputDeviceSelection`), volume
  slider + mute, speed menu (if supported), sleep timer menu, mini-player
  toggle (desktop mini mode: `window_manager` resize to ~380×132, optional
  always-on-top; restore on exit of mini mode).
* Mobile mini-player (artwork, title/artist, play/pause, progress hairline);
  tap/drag up → `NowPlayingPage` full screen (swipe down to close).
* `NowPlayingPage`: large artwork (radius 20, shadow), artwork-derived
  backdrop (use `PaletteGenerator`-like dominant color extraction you
  implement cheaply from a downscaled image, or a blurred artwork when blur
  allowed), title/artist/album, availability/source chips ("Preview",
  "SoundCloud", "Your file", "Downloaded"), transport, seek, volume (desktop),
  like, add to playlist, download (when eligible), share/open on provider,
  sleep timer, speed, lyrics view (synced: auto-scroll + highlight current
  line + tap line to seek; plain fallback; attribution "Lyrics: LRCLIB"),
  queue view, "Playing from <origin>". Error banner for unplayable tracks
  with the localized reason (AvailabilityReason → common_*.arb keys).
* `QueuePage`: now playing + up next with `ReorderableListView` drag-and-drop
  (→ `moveQueueItem`), swipe/remove, play next, clear queue, history section
  (previous items), smart-queue items labeled.
* Keyboard shortcuts (desktop) from `settings.shortcuts.bindings` via
  `Shortcuts`/`Actions` (space must not trigger while typing in a text
  field), plus a **command palette** (Ctrl+K): fuzzy search over navigation
  destinations, player commands, settings sections, playlists, and quick
  track search (library). Shortcuts page in settings is owned by ui-settings;
  you provide the action registry (`lib/ui/actions/command_registry.dart`).

## Shared widgets for other UI agents (`lib/ui/widgets/`, `lib/ui/actions/`)
Build and document: `ArtworkImage` (network/file, placeholder with mark,
size-aware via `EffectiveVisuals.artworkPixels`, fade-in), `TrackTile`
(title/artist/duration/availability badges/now-playing indicator/like;
context menu & long-press sheet: play, play next, add to queue, add to
playlist, like, download / remove download (only if eligible), go to
artist/album, open on <provider> (externalPlaybackUri), copy link),
`TrackListView` (virtualized, selection mode for bulk actions),
`MediaCard` (album/playlist/artist/shelf cards), `ShelfRow` (horizontal
scroller with arrows on desktop), `SectionHeader`, `EmptyState`,
`ErrorState` (maps `FermataException.code` → localized message + retry),
`Skeleton` loaders (shimmer only if animations allowed), `SourceChip`
(provider name text chip — never provider logos), `AvailabilityBadge`
(the four offline categories + preview + external), `FermataButton`
variants, `SearchField`, `SegmentedTabs`, `ConfirmDialog`, `TextInputDialog`,
`AddToPlaylistSheet`, `showFermataToast`. `TrackActions` helpers wrap
playback/favorites/downloads/playlist calls with error handling + toasts.

## Fake kit for widget tests (`test/ui/fakes/`)
In-memory fakes for every contract used through `AppServices` (playback
controller with controllable snapshots, repositories, registry with fake
sources, download manager, recommendations, lyrics, lifecycle, settings
store via `SettingsStore.inMemory()`), plus `pumpFermata(tester, {services,
initialRoute, size})` helper. Other UI agents reuse it — keep it clean.

## Strings
Add to `lib/l10n/fragments/shell_en.arb`/`shell_da.arb` and
`player_en.arb`/`player_da.arb` (natural Danish, not machine-literal), then
`dart run tool/merge_arb.dart && flutter gen-l10n`. All user-visible text
localized.

## Tests (`test/ui/foundation/`)
Theme tokens & contrast; glass on/off/blur-off rendering (golden-free: find
`BackdropFilter` present/absent); shell layout at the three breakpoints;
router redirects (onboarding); player bar controls call the controller;
seek bar; queue reorder calls `moveQueueItem`; navigation does not call
stop/pause; keyboard shortcuts; command palette filtering; lyrics line
highlighting; TrackTile menu shows download only when eligible.
