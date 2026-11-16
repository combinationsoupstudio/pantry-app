import 'package:material_ui/material_ui.dart';

/// Olive green brand with warm neutrals. Surfaces are deliberately distinct:
/// a tinted page, white cards with a visible edge, so every element reads as
/// its own thing at a glance.
const _seed = Color(0xFF4F6B3A);

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
    ok: Color(0xFF2E7D32),
    okContainer: Color(0xFFDDEFD6),
    low: Color(0xFFC77700),
    lowContainer: Color(0xFFFFE7BF),
    out: Color(0xFFC62828),
    outContainer: Color(0xFFFADBD8),
    onContainer: Color(0xFF1C1B17),
  );

  static const dark = StatusColors(
    ok: Color(0xFF8BCF86),
    okContainer: Color(0xFF1F3A1E),
    low: Color(0xFFF3B54A),
    lowContainer: Color(0xFF4A3510),
    out: Color(0xFFF2908A),
    outContainer: Color(0xFF4D1D1A),
    onContainer: Color(0xFFF1EFE8),
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
    surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF1B1D18),
    surfaceContainerLowest: light ? const Color(0xFFFFFFFF) : const Color(0xFF151712),
    outlineVariant: light ? const Color(0xFFD3D6C8) : const Color(0xFF45493F),
  );
  final page = light ? const Color(0xFFF1F2EA) : const Color(0xFF121410);
  final edge = BorderSide(color: scheme.outlineVariant);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  final text = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: page,
    extensions: [light ? StatusColors.light : StatusColors.dark],
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(backgroundColor: page, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: edge),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primaryContainer,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
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
