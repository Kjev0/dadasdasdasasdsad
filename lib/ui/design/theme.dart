import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import '../../settings/performance_profiles.dart';
import 'fermata_colors.dart';
import 'fermata_tokens.dart';

/// Builds the Fermata [ThemeData] with all design-system extensions
/// ([FermataColors], [FermataSpacing], [FermataRadii], [FermataMotion],
/// [FermataTypography]).
///
/// [textScale] scales the type scale itself (useful for previews). The app
/// applies `accessibility.textScale` through `MediaQuery.textScaler` instead
/// (combined with the system setting), so `FermataApp` passes 1.0 here.
/// [visuals] pre-scales the motion tokens (reduced motion / animations off).
ThemeData buildFermataTheme({
  required Brightness brightness,
  AccentChoice accent = AccentChoice.gold,
  bool highContrast = false,
  UiDensity density = UiDensity.comfortable,
  double textScale = 1.0,
  bool largerTargets = false,
  EffectiveVisuals? visuals,
}) {
  final c = FermataColors.resolve(brightness: brightness, accent: accent, highContrast: highContrast);
  final type = FermataTypography.build(primary: c.textPrimary, secondary: c.textSecondary, scale: textScale);
  const radii = FermataRadii();
  final spacing = FermataSpacing.forDensity(density);
  final motion = FermataMotion.from(visuals);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    primaryContainer: Color.alphaBlend(c.accent.withValues(alpha: 0.18), c.surfaceHigh),
    onPrimaryContainer: c.textPrimary,
    secondary: c.accent,
    onSecondary: c.onAccent,
    secondaryContainer: c.surfaceHigh,
    onSecondaryContainer: c.textPrimary,
    tertiary: c.accentText,
    onTertiary: c.onAccent,
    error: c.danger,
    onError: c.isDark ? const Color(0xFF1A0B09) : const Color(0xFFFFFFFF),
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceDim: c.bg,
    surfaceBright: c.surfaceHigh,
    surfaceContainerLowest: c.bg,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surfaceRaised,
    surfaceContainerHigh: c.surfaceHigh,
    surfaceContainerHighest: c.surfaceHigh,
    onSurfaceVariant: c.textSecondary,
    outline: c.outline,
    outlineVariant: c.outlineSubtle,
    shadow: c.shadow,
    scrim: c.scrim,
    inverseSurface: c.textPrimary,
    onInverseSurface: c.bg,
    inversePrimary: c.accent,
    surfaceTint: Colors.transparent,
  );

  final textTheme = TextTheme(
    displayLarge: type.display,
    displayMedium: type.display,
    displaySmall: type.headline,
    headlineLarge: type.headline,
    headlineMedium: type.headline,
    headlineSmall: type.title,
    titleLarge: type.title,
    titleMedium: type.titleSmall,
    titleSmall: type.label.copyWith(fontSize: type.body.fontSize, height: type.body.height),
    bodyLarge: type.body,
    bodyMedium: type.body,
    bodySmall: type.bodySmall,
    labelLarge: type.label,
    labelMedium: type.caption,
    labelSmall: type.caption.copyWith(fontSize: 11 * textScale),
  );

  final controlShape = RoundedRectangleBorder(borderRadius: radii.smAll);
  final minTarget = largerTargets ? 48.0 : spacing.controlHeight;

  ButtonStyle baseButton(Color bg, Color fg) => ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.textTertiary : fg,
        ),
        minimumSize: WidgetStatePropertyAll(Size(64, minTarget)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        shape: WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(type.label),
        elevation: const WidgetStatePropertyAll(0),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: FermataTypography.fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    cardColor: c.surface,
    dividerColor: c.outlineSubtle,
    hintColor: c.textTertiary,
    disabledColor: c.textTertiary,
    hoverColor: c.textPrimary.withValues(alpha: 0.05),
    focusColor: c.accent.withValues(alpha: 0.18),
    highlightColor: c.textPrimary.withValues(alpha: 0.04),
    splashColor: c.textPrimary.withValues(alpha: 0.06),
    splashFactory: InkRipple.splashFactory,
    shadowColor: c.shadow,
    visualDensity: density == UiDensity.compact ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: largerTargets ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
    iconTheme: IconThemeData(color: c.textSecondary, size: 22),
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.title,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radii.mdAll, side: BorderSide(color: c.outlineSubtle)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: radii.lgAll, side: BorderSide(color: c.outlineSubtle)),
      titleTextStyle: type.title,
      contentTextStyle: type.body.copyWith(color: c.textSecondary),
      barrierColor: c.scrim,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surfaceRaised,
      modalBarrierColor: c.scrim,
      showDragHandle: true,
      dragHandleColor: c.outline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radii.xl))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: c.accent.withValues(alpha: 0.16),
      indicatorShape: RoundedRectangleBorder(borderRadius: radii.smAll),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => type.caption.copyWith(
          color: s.contains(WidgetState.selected) ? c.textPrimary : c.textSecondary,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.accentText : c.textSecondary, size: 24),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: c.accent.withValues(alpha: 0.16),
      selectedIconTheme: IconThemeData(color: c.accentText),
      unselectedIconTheme: IconThemeData(color: c.textSecondary),
      selectedLabelTextStyle: type.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: type.caption,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.accent,
      inactiveTrackColor: c.outline,
      thumbColor: c.textPrimary,
      overlayColor: c.accent.withValues(alpha: 0.14),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(borderRadius: radii.mdAll, side: BorderSide(color: c.outline)),
      textStyle: type.body,
      labelTextStyle: WidgetStatePropertyAll(type.body),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surfaceHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(c.shadow),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radii.mdAll, side: BorderSide(color: c.outline)),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: radii.xsAll, border: Border.all(color: c.outline)),
      textStyle: type.caption.copyWith(color: c.textPrimary),
      waitDuration: const Duration(milliseconds: 500),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceHigh,
      contentTextStyle: type.body.copyWith(color: c.textPrimary),
      actionTextColor: c.accentText,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: radii.mdAll, side: BorderSide(color: c.outline)),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surfaceHigh,
      // Inputs sit on surfaceHigh, where tertiary text is too faint.
      hintStyle: type.body.copyWith(color: c.textSecondary),
      labelStyle: type.body.copyWith(color: c.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: radii.smAll, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radii.smAll, borderSide: BorderSide(color: c.outlineSubtle)),
      focusedBorder: OutlineInputBorder(borderRadius: radii.smAll, borderSide: BorderSide(color: c.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: radii.smAll, borderSide: BorderSide(color: c.danger)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: baseButton(c.accent, c.onAccent)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: baseButton(c.surfaceHigh, c.textPrimary)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: baseButton(Colors.transparent, c.textPrimary).copyWith(
        side: WidgetStatePropertyAll(BorderSide(color: c.outline)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: baseButton(Colors.transparent, c.accentText).copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.textTertiary
              : s.contains(WidgetState.selected)
                  ? c.accentText
                  : c.textSecondary,
        ),
        minimumSize: WidgetStatePropertyAll(Size.square(largerTargets ? 48 : 40)),
        shape: WidgetStatePropertyAll(controlShape),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceHigh,
      selectedColor: c.accent.withValues(alpha: 0.18),
      side: BorderSide(color: c.outlineSubtle),
      shape: RoundedRectangleBorder(borderRadius: radii.smAll),
      labelStyle: type.caption.copyWith(color: c.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : Colors.transparent),
      checkColor: WidgetStatePropertyAll(c.onAccent),
      side: BorderSide(color: c.outline, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.outline),
    ),
    dividerTheme: DividerThemeData(color: c.outlineSubtle, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
      titleTextStyle: type.body,
      subtitleTextStyle: type.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: radii.smAll),
      selectedColor: c.textPrimary,
      selectedTileColor: c.accent.withValues(alpha: 0.12),
      minVerticalPadding: 6,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.outline,
      circularTrackColor: Colors.transparent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textTertiary.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.textPrimary,
      unselectedLabelColor: c.textSecondary,
      labelStyle: type.label,
      unselectedLabelStyle: type.label,
      indicatorColor: c.accent,
      dividerColor: c.outlineSubtle,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent.withValues(alpha: 0.18) : Colors.transparent,
        ),
        foregroundColor: WidgetStatePropertyAll(c.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: c.outline)),
        textStyle: WidgetStatePropertyAll(type.label),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    extensions: [c, spacing, radii, motion, type],
  );
}
