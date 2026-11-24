import 'package:material_ui/material_ui.dart';

/// The app's colour (v0.18 glow-up, #38). Two looks, picked in Settings:
/// **Warm pantry** (v0.10, Chris 16 Nov) made richer: herb green, saffron,
/// tomato on cream, with a deep olive bar; and **Market fresh**, the bold
/// one: deep teal, citrus and coral on cool white. Headings in Fraunces,
/// everything else in Nunito Sans. Every status colour passes WCAG AA on
/// its page (test/v018_theme_test.dart).
enum PantryLook {
  warm('Warm pantry'),
  market('Market fresh');

  const PantryLook(this.label);
  final String label;

  /// Market fresh is the default (Chris, 24 Nov 2026: "I like Market Fresh").
  static PantryLook fromName(Object? name) => name == 'warm' ? PantryLook.warm : PantryLook.market;
}

/// One look in one brightness: every colour the theme is built from.
@immutable
class Palette {
  const Palette({
    required this.page,
    required this.shelf,
    required this.edge,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.ink,
    required this.inkSoft,
    required this.outline,
    required this.ok,
    required this.okContainer,
    required this.low,
    required this.lowContainer,
    required this.out,
    required this.outContainer,
    required this.bar,
    required this.onBar,
    required this.barSoft,
    required this.meals,
    required this.onMeals,
    required this.dates,
    required this.onDates,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
  });

  final Color page, shelf, edge, primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color accent, onAccent, accentContainer, onAccentContainer, ink, inkSoft, outline;
  final Color ok, okContainer, low, lowContainer, out, outContainer;

  /// The bottom bar and Home's header (v0.18, #42): a deep band of the main
  /// colour, its pill in [accent]; [barSoft] for quieter words on it.
  final Color bar, onBar, barSoft;

  /// Home's three tiles: the list (accent), meals, dates.
  final Color meals, onMeals, dates, onDates;
  final Color surfaceLow, surface, surfaceHigh;

  static Palette of(PantryLook look, Brightness b) => switch ((look, b)) {
    (PantryLook.warm, Brightness.light) => warmLight,
    (PantryLook.warm, Brightness.dark) => warmDark,
    (PantryLook.market, Brightness.light) => marketLight,
    (PantryLook.market, Brightness.dark) => marketDark,
  };

  static const warmLight = Palette(
    page: Color(0xFFF8F0E0),
    shelf: Color(0xFFFFFCF6),
    edge: Color(0xFFEADCC2),
    primary: Color(0xFF46661B),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD9EBB0),
    onPrimaryContainer: Color(0xFF1C2A05),
    accent: Color(0xFFE39B17),
    onAccent: Color(0xFF2E1C00),
    accentContainer: Color(0xFFFFE6B3),
    onAccentContainer: Color(0xFF3D2600),
    ink: Color(0xFF2A231B),
    inkSoft: Color(0xFF6B5E4D),
    outline: Color(0xFFA89B85),
    ok: Color(0xFF3B7526),
    okContainer: Color(0xFFDCF0C8),
    low: Color(0xFF975A00),
    lowContainer: Color(0xFFFFE6B3),
    out: Color(0xFFC2381F),
    outContainer: Color(0xFFFFDCD2),
    bar: Color(0xFF2F3E14),
    onBar: Color(0xFFF8F0E0),
    barSoft: Color(0xFFD9EBB0),
    meals: Color(0xFFC5E08F),
    onMeals: Color(0xFF1C2A05),
    dates: Color(0xFFFFB8A6),
    onDates: Color(0xFF3A0D05),
    surfaceLow: Color(0xFFFCF4E6),
    surface: Color(0xFFF5EAD5),
    surfaceHigh: Color(0xFFEEE1C8),
  );

  static const warmDark = Palette(
    page: Color(0xFF1B1813),
    shelf: Color(0xFF26221B),
    edge: Color(0xFF3D372D),
    primary: Color(0xFFBCD88A),
    onPrimary: Color(0xFF223010),
    primaryContainer: Color(0xFF3B4D1C),
    onPrimaryContainer: Color(0xFFE2F0C4),
    accent: Color(0xFFE39B17),
    onAccent: Color(0xFF2E1C00),
    accentContainer: Color(0xFF4A3812),
    onAccentContainer: Color(0xFFFFE6B3),
    ink: Color(0xFFF6EEDF),
    inkSoft: Color(0xFFC9BEAC),
    outline: Color(0xFF8C8170),
    ok: Color(0xFFA9CF86),
    okContainer: Color(0xFF2F3D1C),
    low: Color(0xFFF2BE5C),
    lowContainer: Color(0xFF4A3812),
    out: Color(0xFFFF9C86),
    outContainer: Color(0xFF532319),
    bar: Color(0xFF121A06),
    onBar: Color(0xFFF3ECDF),
    barSoft: Color(0xFFD9EBB0),
    meals: Color(0xFFC5E08F),
    onMeals: Color(0xFF1C2A05),
    dates: Color(0xFFFFB8A6),
    onDates: Color(0xFF3A0D05),
    surfaceLow: Color(0xFF221E18),
    surface: Color(0xFF2A251E),
    surfaceHigh: Color(0xFF332D25),
  );

  static const marketLight = Palette(
    page: Color(0xFFF1F6F3),
    shelf: Colors.white,
    edge: Color(0xFFD5E3DC),
    primary: Color(0xFF0C6B58),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFBFEBDD),
    onPrimaryContainer: Color(0xFF00382D),
    accent: Color(0xFFF5B700),
    onAccent: Color(0xFF2E2300),
    accentContainer: Color(0xFFFFEDB0),
    onAccentContainer: Color(0xFF3A2C00),
    ink: Color(0xFF14231F),
    inkSoft: Color(0xFF4E625B),
    outline: Color(0xFF8AA39A),
    ok: Color(0xFF1B7F52),
    okContainer: Color(0xFFD3F2E2),
    low: Color(0xFF9A5E00),
    lowContainer: Color(0xFFFFEDB0),
    out: Color(0xFFC93A26),
    outContainer: Color(0xFFFFDDD6),
    bar: Color(0xFF0A3D33),
    onBar: Color(0xFFE6F4EF),
    barSoft: Color(0xFFA8E6D3),
    meals: Color(0xFF7FD6C1),
    onMeals: Color(0xFF00382D),
    dates: Color(0xFFFF9A86),
    onDates: Color(0xFF3A0D05),
    surfaceLow: Color(0xFFF7FBF9),
    surface: Color(0xFFE9F2EE),
    surfaceHigh: Color(0xFFDDEAE4),
  );

  static const marketDark = Palette(
    page: Color(0xFF101815),
    shelf: Color(0xFF18231F),
    edge: Color(0xFF2B3C36),
    primary: Color(0xFF7FD6C1),
    onPrimary: Color(0xFF00382D),
    primaryContainer: Color(0xFF115346),
    onPrimaryContainer: Color(0xFFBFEBDD),
    accent: Color(0xFFF5B700),
    onAccent: Color(0xFF2E2300),
    accentContainer: Color(0xFF4A3A08),
    onAccentContainer: Color(0xFFFFEDB0),
    ink: Color(0xFFE6F4EF),
    inkSoft: Color(0xFFA9C2BA),
    outline: Color(0xFF6E8A81),
    ok: Color(0xFF7FD9A8),
    okContainer: Color(0xFF173D2C),
    low: Color(0xFFF5C24A),
    lowContainer: Color(0xFF4A3A08),
    out: Color(0xFFFF9A86),
    outContainer: Color(0xFF552219),
    bar: Color(0xFF06241E),
    onBar: Color(0xFFE6F4EF),
    barSoft: Color(0xFFA8E6D3),
    meals: Color(0xFF7FD6C1),
    onMeals: Color(0xFF00382D),
    dates: Color(0xFFFF9A86),
    onDates: Color(0xFF3A0D05),
    surfaceLow: Color(0xFF131D1A),
    surface: Color(0xFF1C2925),
    surfaceHigh: Color(0xFF24332E),
  );
}

const headingFont = 'Fraunces';
const bodyFont = 'Nunito Sans';

/// The look's own colours for pages that paint with them (Home's header).
@immutable
class LookColors extends ThemeExtension<LookColors> {
  const LookColors(this.palette);
  final Palette palette;

  static Palette of(BuildContext context) => Theme.of(context).extension<LookColors>()!.palette;

  @override
  LookColors copyWith() => this;

  @override
  LookColors lerp(LookColors? other, double t) => (t < 0.5 || other == null) ? this : other;
}

/// What a colour means, the same on every page.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.ok,
    required this.okContainer,
    required this.low,
    required this.lowContainer,
    required this.out,
    required this.outContainer,
    required this.onContainer,
  });

  factory StatusColors.from(Palette p) => StatusColors(
    ok: p.ok,
    okContainer: p.okContainer,
    low: p.low,
    lowContainer: p.lowContainer,
    out: p.out,
    outContainer: p.outContainer,
    onContainer: p.ink,
  );

  final Color ok, okContainer, low, lowContainer, out, outContainer, onContainer;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) => (t < 0.5 || other == null) ? this : other;
}

ThemeData buildTheme(Brightness brightness, {PantryLook look = PantryLook.market}) {
  final p = Palette.of(look, brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: p.accent,
    secondaryContainer: p.accentContainer,
    onSecondaryContainer: p.onAccentContainer,
    tertiary: p.out,
    tertiaryContainer: p.outContainer,
    error: p.out,
    surface: p.shelf,
    onSurface: p.ink,
    onSurfaceVariant: p.inkSoft,
    surfaceContainerLowest: p.shelf,
    surfaceContainerLow: p.surfaceLow,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
    outline: p.outline,
    outlineVariant: p.edge,
  );
  final page = p.page;
  final edge = BorderSide(color: scheme.outlineVariant);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness, fontFamily: bodyFont);
  final t = base.textTheme;
  TextStyle? heading(TextStyle? s, {double? size}) =>
      s?.copyWith(fontFamily: headingFont, fontWeight: FontWeight.w600, fontSize: size, letterSpacing: -0.2);
  final text = t.copyWith(
    displaySmall: heading(t.displaySmall),
    headlineLarge: heading(t.headlineLarge),
    headlineMedium: heading(t.headlineMedium, size: 30),
    headlineSmall: heading(t.headlineSmall),
    titleLarge: heading(t.titleLarge, size: 22),
  );

  return base.copyWith(
    scaffoldBackgroundColor: page,
    extensions: [StatusColors.from(p), LookColors(p)],
    textTheme: text.copyWith(
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.35),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      // A soft lift off the page, tinted to the look, not grey (v0.18).
      elevation: 1.5,
      shadowColor: p.primary.withValues(alpha: 0.12),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: edge),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.bar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: p.accent,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.onAccent : p.onBar),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? p.onBar : p.onBar.withValues(alpha: 0.78),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      side: edge,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      showCheckmark: false,
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(scheme.surface),
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(edge),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 3,
      extendedTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: text.titleSmall,
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: edge),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// The colour for a stock level: out, low or fine.
Color stockColor(BuildContext context, {required bool out, required bool low}) {
  final c = StatusColors.of(context);
  return out
      ? c.out
      : low
      ? c.low
      : c.ok;
}
