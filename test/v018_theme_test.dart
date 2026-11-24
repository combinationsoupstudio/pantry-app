import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/ui/theme.dart';

// v0.18 (#38): both looks, light and dark, keep every status readable
// (WCAG AA, 4.5:1) on the page and the cards.

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

void main() {
  for (final look in PantryLook.values) {
    for (final b in Brightness.values) {
      test('${look.name} ${b.name}: every pair passes AA', () {
        final p = Palette.of(look, b);
        final pairs = {
          'ok on card': (p.ok, p.shelf),
          'low on card': (p.low, p.shelf),
          'out on card': (p.out, p.shelf),
          'low on page': (p.low, p.page),
          'primary on card': (p.primary, p.shelf),
          'ink on ok chip': (p.ink, p.okContainer),
          'ink on low chip': (p.ink, p.lowContainer),
          'ink on out chip': (p.ink, p.outContainer),
          'bar labels': (p.onBar, p.bar),
          'bar pill icon and add button': (p.onAccent, p.accent),
          'soft ink on card': (p.inkSoft, p.shelf),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
        }
      });
    }
  }

  test('the look is read from the setting, warm when unknown', () {
    expect(PantryLook.fromName('market'), PantryLook.market);
    expect(PantryLook.fromName(null), PantryLook.warm);
    expect(buildTheme(Brightness.light, look: PantryLook.market).colorScheme.primary, Palette.marketLight.primary);
  });
}
