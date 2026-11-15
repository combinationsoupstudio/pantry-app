import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the household's state is kept. Phase 0 keeps it on the phone;
/// phase 1 adds a sync backend behind the same interface.
abstract interface class StorageBackend {
  Future<Map<String, Object?>?> load();
  Future<void> save(Map<String, Object?> data);
}

/// Keeps state in memory only. Used by tests.
class MemoryBackend implements StorageBackend {
  MemoryBackend([this.data]);

  Map<String, Object?>? data;
  int saves = 0;

  @override
  Future<Map<String, Object?>?> load() async => data;

  @override
  Future<void> save(Map<String, Object?> data) async {
    this.data = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
    saves++;
  }
}

/// Keeps state in a JSON file in the app's private documents folder.
/// Writes go to a temp file first, then replace the real one, so a crash
/// mid-write never leaves a half-written file.
class FileBackend implements StorageBackend {
  FileBackend({this.fileName = 'household.json'});

  final String fileName;
  Future<void> _queue = Future.value();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<Map<String, Object?>?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    if (text.trim().isEmpty) return null;
    return jsonDecode(text) as Map<String, Object?>;
  }

  @override
  Future<void> save(Map<String, Object?> data) {
    // Serialise writes so two quick taps never interleave.
    return _queue = _queue.then((_) async {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(file.path);
    });
  }
}
