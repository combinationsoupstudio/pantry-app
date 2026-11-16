import 'package:material_ui/material_ui.dart';

/// Warm pantry (v0.10, Chris 16 Nov): a cream page like a pantry shelf
/// liner, olive green for doing things, tomato red for "out", mustard for
/// "low". Headings in Fraunces, everything else in Nunito Sans. Cards sit on
/// the page with a soft edge so each thing reads as its own at a glance.
const _seed = Color(0xFF5A6B2E);
const _tomato = Color(0xFFC8452F);

/// The palette, named, for the few places that draw their own colour.
abstract final class Pantry {
  static const cream = Color(0xFFF6EFE2);
  static const shelf = Color(0xFFFFFBF4);
  static const crust = Color(0xFFE7DBC6);
  static const olive = Color(0xFF55682A);
  static const oliveSoft = Color(0xFFE4E8CC);
  static const tomato = _tomato;
  static const tomatoSoft = Color(0xFFF8DED6);
  static const mustard = Color(0xFFB9800F);
  static const mustardSoft = Color(0xFFF8E8C4);
  static const ink = Color(0xFF2C2620);
  static const nightPage = Color(0xFF1B1813);
  static const nightShelf = Color(0xFF26221B);
  static const nightCrust = Color(0xFF3D372D);
}

const headingFont = 'Fraunces';
const bodyFont = 'Nunito Sans';

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

  final Color ok, okContainer, low, lowContainer, out, outContainer, onContainer;

  static const light = StatusColors(
    ok: Pantry.olive,
    okContainer: Pantry.oliveSoft,
    low: Pantry.mustard,
    lowContainer: Pantry.mustardSoft,
    out: Pantry.tomato,
    outContainer: Pantry.tomatoSoft,
    onContainer: Pantry.ink,
  );

  static const dark = StatusColors(
    ok: Color(0xFFB5C98A),
    okContainer: Color(0xFF333B1F),
    low: Color(0xFFE9B85A),
    lowContainer: Color(0xFF4A3812),
    out: Color(0xFFF0947F),
    outContainer: Color(0xFF4F2219),
    onContainer: Color(0xFFF3ECDF),
  );

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) => (t < 0.5 || other == null) ? this : other;
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    primary: light ? Pantry.olive : const Color(0xFFBFD08E),
    onPrimary: light ? Colors.white : const Color(0xFF263010),
    primaryContainer: light ? Pantry.oliveSoft : const Color(0xFF3B4720),
    onPrimaryContainer: light ? const Color(0xFF1E2808) : const Color(0xFFE4ECC4),
    secondaryContainer: light ? const Color(0xFFEDE3CF) : const Color(0xFF3A3326),
    onSecondaryContainer: light ? Pantry.ink : const Color(0xFFF0E6D2),
    tertiary: light ? _tomato : const Color(0xFFF0947F),
    error: light ? _tomato : const Color(0xFFF0947F),
    surface: light ? Pantry.shelf : Pantry.nightShelf,
    onSurface: light ? Pantry.ink : const Color(0xFFF3ECDF),
    onSurfaceVariant: light ? const Color(0xFF6B6153) : const Color(0xFFC9BEAC),
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF15120E),
    surfaceContainerLow: light ? const Color(0xFFFBF5EA) : const Color(0xFF221E18),
    surfaceContainer: light ? const Color(0xFFF3EBDC) : const Color(0xFF2A251E),
    surfaceContainerHigh: light ? const Color(0xFFEDE3D1) : const Color(0xFF332D25),
    outline: light ? const Color(0xFFA89B85) : const Color(0xFF8C8170),
    outlineVariant: light ? Pantry.crust : Pantry.nightCrust,
  );
  final page = light ? Pantry.cream : Pantry.nightPage;
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
    extensions: [light ? StatusColors.light : StatusColors.dark],
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
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: edge),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      side: edge,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
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
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
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
