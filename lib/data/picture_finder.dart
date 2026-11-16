/// Finds pictures for items that have none, quietly, one at a time.
///
/// Scanned items are looked up by barcode; typed or imported ones by name
/// (`picture_match.dart`). Open Food Facts limits searches, so the finder
/// waits [gap] between them: a first run over a whole household takes a few
/// minutes, and pictures appear as they are found. ADR 0006.
library;

import 'dart:async';

import '../logic/picture_match.dart';
import 'household_store.dart';
import 'open_food_facts.dart';

class PictureFinder {
  PictureFinder(this.store, {OpenFoodFacts? off, this.gap = const Duration(seconds: 6), this.wait})
    : _offOverride = off;

  /// The finder the app runs; null in tests.
  static PictureFinder? instance;

  final HouseholdStore store;
  final OpenFoodFacts? _offOverride;
  final Duration gap;

  /// How to wait between requests (tests pass one that does not).
  final Future<void> Function(Duration)? wait;

  OpenFoodFacts get off => _offOverride ?? OpenFoodFacts.instance;
  bool _running = false;
  bool _again = false;

  /// Looks again soon (after an item is added or renamed). Safe to call often.
  void nudge() {
    if (_running) {
      _again = true;
      return;
    }
    unawaited(run());
  }

  Future<void> _pause() => (wait ?? Future<void>.delayed)(gap);

  /// Works through every item that wants a picture. Stops early, leaving the
  /// rest for next time, when there is no connection.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      do {
        _again = false;
        final todo = store.items.where((i) => i.wantsPicture).map((i) => i.id).toList();
        for (final id in todo) {
          final item = store.item(id);
          if (item == null || !item.wantsPicture) continue;
          String? url;
          var byName = false;
          final code = item.barcode;
          if (code != null) {
            url = (await off.lookup(code))?.imageUrl;
            await _pause();
          }
          if (url == null) {
            for (final q in pictureQueries(item.name)) {
              final match = bestPictureMatch(q, await off.search(q));
              await _pause();
              if (match != null) {
                url = match.imageUrl;
                byName = true;
                break;
              }
            }
          }
          // The item may have changed while we waited; never overwrite a
          // picture someone chose in the meantime.
          final now = store.item(id);
          if (now == null || !now.wantsPicture) continue;
          if (url != null) {
            await store.setPicture(id, url, byName: byName);
          } else {
            await store.markPictureTried(id);
          }
        }
      } while (_again);
    } on LookupFailed {
      // No signal or the service is busy: try again next time.
    } finally {
      _running = false;
    }
  }
}
