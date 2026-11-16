/// "Back up now" and "Restore": the whole household in one file.
///
/// The file holds everything the app keeps (stock, list, recipes, prices,
/// history) and the household's own photos inside it, so a lost or broken
/// phone loses nothing that was backed up. Product pictures are not copied:
/// their addresses are kept and they download again. ADR 0007.
library;

import 'dart:convert';
import 'dart:io';

import 'household_store.dart';

const backupKind = 'pantry-app-backup';

/// A backup file's name for [when]: pantry-backup-2026-11-16-1642.json.
String backupFileName(DateTime when) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'pantry-backup-${when.year}-${two(when.month)}-${two(when.day)}-${two(when.hour)}${two(when.minute)}.json';
}

/// The backup as JSON text: the household's data plus its photos.
String makeBackup(HouseholdStore store, {required DateTime now, String appVersion = ''}) {
  final photos = <String, String>{};
  for (final i in store.items) {
    final p = i.photoPath;
    if (p == null || photos.containsKey(p)) continue;
    final f = File(p);
    if (f.existsSync()) photos[p] = base64Encode(f.readAsBytesSync());
  }
  return jsonEncode({
    'kind': backupKind,
    'made': now.toIso8601String(),
    'app': appVersion,
    'data': store.toJson(),
    'photos': photos,
  });
}

/// What a restore brought back.
class RestoreResult {
  const RestoreResult(this.items, this.photos, this.made);
  final int items;
  final int photos;
  final DateTime? made;
}

/// Replaces the household with a backup's contents. Photos are written into
/// [photoDir] under new names and the items pointed at them. Throws
/// [FormatException] for anything that is not a pantry backup.
Future<RestoreResult> restoreBackup(HouseholdStore store, String text, Directory photoDir) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const FormatException('That file is not a pantry backup');
  }
  if (decoded is! Map || decoded['kind'] != backupKind || decoded['data'] is! Map) {
    throw const FormatException('That file is not a pantry backup');
  }
  final data = (decoded['data'] as Map).cast<String, Object?>();
  final photos = (decoded['photos'] as Map? ?? const {}).cast<String, Object?>();

  // Put each photo back on this phone and remember where it went.
  final moved = <String, String>{};
  if (photos.isNotEmpty && !photoDir.existsSync()) photoDir.createSync(recursive: true);
  var n = 0;
  for (final e in photos.entries) {
    final v = e.value;
    if (v is! String) continue;
    try {
      final name = e.key.split(RegExp(r'[\\/]')).last;
      final path = '${photoDir.path}/restored-${n++}-$name';
      File(path).writeAsBytesSync(base64Decode(v));
      moved[e.key] = path;
    } on FormatException {
      continue;
    }
  }
  final items = [
    for (final raw in (data['items'] as List? ?? const []))
      if (raw is Map)
        {...raw.cast<String, Object?>(), if (raw['photoPath'] is String) 'photoPath': moved[raw['photoPath']]},
  ];
  await store.restore({...data, 'items': items});
  return RestoreResult(items.length, moved.length, DateTime.tryParse('${decoded['made']}'));
}
