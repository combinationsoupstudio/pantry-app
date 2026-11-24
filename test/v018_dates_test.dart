import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_app/data/household_store.dart';
import 'package:pantry_app/data/storage_backend.dart';
import 'package:pantry_app/logic/supplies.dart';
import 'package:pantry_app/models/models.dart';

// v0.18 (#36): a date is a use by or a best before, never both.

final today = DateTime(2026, 11, 24, 9); // a Tuesday

Future<HouseholdStore> newStore() async {
  final s = HouseholdStore(MemoryBackend(), clock: () => today);
  await s.load();
  return s;
}

StockBatch d(double amount, int day, {DateKind kind = DateKind.useBy, bool guessed = false}) =>
    StockBatch(amount: amount, useBy: DateTime(2026, 11, day), kind: kind, guessed: guessed);

void main() {
  group('the kind of date', () {
    test('old batches with no kind read as use by; best before survives a round trip', () {
      final old = StockBatch.fromJson({'amount': 1, 'useBy': DateTime(2026, 11, 30).toIso8601String()});
      expect(old.kind, DateKind.useBy);
      expect(old.toJson().containsKey('kind'), isFalse, reason: 'older phones see what they saw before');
      final bb = d(2, 30, kind: DateKind.bestBefore);
      expect(StockBatch.fromJson(bb.toJson()), bb);
    });

    test('the same day merges only with the same kind, use by first', () {
      final n = normaliseBatches([d(1, 30, kind: DateKind.bestBefore), d(1, 30), d(2, 30)], 10);
      expect(n, [d(3, 30), d(1, 30, kind: DateKind.bestBefore)]);
    });

    test('an item remembers its kind, and a guessed top-up takes it', () async {
      final s = await newStore();
      final beans = await s.addItem(
        name: 'Baked beans',
        locationId: 'pantry',
        quantity: 2,
        useBy: DateTime(2027, 5, 1),
        dateKind: DateKind.bestBefore,
      );
      expect(s.item(beans.id)!.batches.single.kind, DateKind.bestBefore);
      expect(s.item(beans.id)!.dateKind, DateKind.bestBefore);
      await s.adjust(beans.id, 1);
      final after = s.item(beans.id)!;
      expect(after.datedAmount, 3, reason: 'the top-up was guessed the same keep, so it joined the batch');
      expect(after.batches.every((b) => b.kind == DateKind.bestBefore), isTrue);
      final back = StockItem.fromJson(after.toJson());
      expect(back.dateKind, DateKind.bestBefore);
      expect(back.batches, after.batches);
    });

    test('dating stock sets the kind', () async {
      final s = await newStore();
      final m = await s.addItem(name: 'Milk', locationId: 'pantry', quantity: 2);
      await s.dateStock(m.id, 2, DateTime(2026, 11, 28), kind: DateKind.useBy);
      await s.dateStock(m.id, 0, DateTime(2026, 11, 29));
      expect(s.item(m.id)!.batches.single.kind, DateKind.useBy);
    });
  });

  group('what the row says', () {
    String n(double a) => a.toStringAsFixed(0);
    StockItem withBatch(StockBatch b) => StockItem(
      id: 'x',
      name: 'X',
      locationId: 'pantry',
      quantity: b.amount,
      unit: '',
      target: 0,
      updatedAt: today,
      updatedBy: '',
      batches: [b],
    );

    test('past dates say which kind they were', () {
      expect(eatFirstHint(withBatch(d(1, 20)), today, n), '1 past use by');
      expect(eatFirstHint(withBatch(d(1, 20, kind: DateKind.bestBefore)), today, n), '1 past best before');
    });

    test('a close best before is not an order to eat it', () {
      expect(eatFirstHint(withBatch(d(2, 27, kind: DateKind.bestBefore)), today, n), '2 best before Fri');
      expect(eatFirstHint(withBatch(d(2, 27)), today, n), 'eat 2 by Fri');
    });

    test('advice once the date has gone', () {
      expect(DateKind.useBy.pastAdvice, "Past use by. Don't eat");
      expect(DateKind.bestBefore.pastAdvice, 'Past best before. Check it');
    });
  });
}
