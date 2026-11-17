import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/logic/count_or_measure.dart';

void main() {
  test('used bit by bit is measured; packs, jars and tins are counted', () {
    String g(String name, [double size = 500, String unit = 'g']) =>
        guessKeepAs(name, packSize: size, unit: unit).toString();
    expect(g('Strawberry jam'), 'count jars');
    expect(g("Leggo's passata", 700), 'count jars');
    expect(g('Diced tomatoes tin', 400), 'count cans');
    expect(g('Baked beans', 420), 'count cans');
    expect(g('Coconut milk', 400, 'ml'), 'count cans');
    expect(g('Tuna in springwater', 95), 'count cans');
    expect(g('Olive oil', 750, 'ml'), 'measure');
    expect(g('Soy sauce', 500, 'ml'), 'measure');
    expect(g('Plain flour', 1000), 'measure');
    expect(g('White rice', 2000), 'measure');
    expect(g('Rolled oats', 750), 'measure');
    expect(g('UHT milk', 1000, 'ml'), 'measure');
    expect(g('Instant noodles', 85), 'count packs');
    expect(g('Toilet paper', 0, ''), 'count rolls');
    expect(g('Batteries AA', 0, ''), 'count packs');
    expect(g('Hydralyte sachets', 0, ''), 'count items');
    // No pack size known: counted, even if it is used bit by bit.
    expect(g('Olive oil', 0, ''), 'count items');
  });
}
