import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'household_store.dart';
import 'storage_backend.dart';

/// The household's sync server (Cloudflare Worker, studio account). ADR 0010.
const syncServer = 'https://pantry-sync.combinationsoupstudio.workers.dev';

/// Kinds the server keeps but never deletes.
const _appendOnly = {'prices', 'activity'};

/// How this phone joins a household that already has a list.
enum JoinMode {
  /// This phone's list is replaced by the household's.
  useHousehold,

  /// This phone's things are added to the household's list.
  addMine,
}

/// Opens the household's live line (a websocket).
typedef LiveConnect = WebSocketChannel Function(Uri uri, Map<String, String> headers);

WebSocketChannel _connect(Uri uri, Map<String, String> headers) => IOWebSocketChannel.connect(uri, headers: headers);

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Keeps this phone and the household's server in step.
///
/// Each sync sends what changed on this phone since the last sync (found by
/// comparing every record with a snapshot of what was last in step), then takes
/// everything the household changed since its cursor. Stock amounts go as a
/// change (+2, -1) so two people using the same thing both count.
class SyncService extends ChangeNotifier {
  SyncService(
    this.store, {
    StorageBackend? backend,
    http.Client? client,
    this.server = syncServer,
    DateTime Function()? clock,
    LiveConnect? connect,
    this.pushDelay = const Duration(milliseconds: 800),
  }) : _backend = backend ?? FileBackend(fileName: 'sync.json'),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _connectLive = connect ?? _connect;

  static SyncService? instance;

  final HouseholdStore store;
  final String server;
  final StorageBackend _backend;
  final http.Client _client;
  final DateTime Function() _clock;
  final LiveConnect _connectLive;

  /// How long after a change it is sent (changes made together go together).
  final Duration pushDelay;

  /// This phone, so it can ignore news of its own changes.
  String _phone = _randomId();

  String? _household;
  String? _token;
  int _cursor = 0;
  Map<String, Map<String, String>> _snapshot = {};
  DateTime? _lastSync;
  String? _error;
  bool _busy = false;
  Future<void>? _running;
  bool _again = false;

  Timer? _pushTimer;
  Timer? _pollTimer;
  bool _live = false;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _socketSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _lineUp = false;
  int _retries = 0;

  /// True while the household's live line is open: changes arrive within a second or two.
  bool get liveLine => _lineUp;

  String? get household => _household;
  bool get joined => _household != null && _token != null;
  DateTime? get lastSync => _lastSync;
  String? get error => _error;
  bool get busy => _busy;

  /// Changes waiting to go (0 when in step).
  int get waiting => joined ? _changes(store.syncRecords()).length : 0;

  Future<void> load() async {
    final d = await _backend.load();
    if (d == null) return;
    _household = d['household'] as String?;
    _token = d['token'] as String?;
    _cursor = (d['cursor'] as num?)?.toInt() ?? 0;
    _phone = (d['phone'] as String?) ?? _phone;
    final last = d['lastSync'] as String?;
    _lastSync = last == null ? null : DateTime.tryParse(last);
    _snapshot = {
      for (final e in ((d['snapshot'] as Map?) ?? {}).entries)
        e.key as String: {for (final r in (e.value as Map).entries) r.key as String: r.value as String},
    };
  }

  Future<void> _save() => _backend.save({
    'household': _household,
    'token': _token,
    'cursor': _cursor,
    'phone': _phone,
    'lastSync': _lastSync?.toIso8601String(),
    'snapshot': _snapshot,
  });

  // ---------------------------------------------------------------- joining

  /// Starts a household with this phone's list. Returns the join code.
  Future<String> start() async {
    final r = await _post('/households', {});
    _household = r['household'] as String;
    _token = r['token'] as String;
    _cursor = 0;
    _snapshot = {};
    await _save();
    await syncNow();
    return r['code'] as String;
  }

  /// A fresh one-use code (lasts 48 hours) for another phone.
  Future<String> invite() async {
    final r = await _post('/h/$_household/invite', {}, auth: true);
    return r['code'] as String;
  }

  /// Joins with a code from another phone, "ABCD2345-123456".
  Future<void> join(String code, JoinMode mode) async {
    final clean = code.trim().toUpperCase().replaceAll(' ', '');
    final m = RegExp(r'^([A-Z0-9]{8})-?(\d{6})$').firstMatch(clean);
    if (m == null) throw const SyncException('That code does not look right. It looks like ABCD2345-123456.');
    final household = m.group(1)!;
    final r = await _post('/h/$household/join', {'code': m.group(2)});
    _household = household;
    _token = r['token'] as String;
    _cursor = 0;
    if (mode == JoinMode.useHousehold) {
      // Everything here counts as already in step; whatever the household
      // does not have is then taken off this phone.
      _snapshot = _encodeAll(store.syncRecords());
      await _save();
      await syncNow();
      final have = await _fetchIds();
      final mine = store.syncRecords();
      final gone = <(String, String, Map<String, Object?>?)>[
        for (final kind in mine.keys)
          if (!_appendOnly.contains(kind) && kind != 'settings')
            for (final id in mine[kind]!.keys)
              if (!(have[kind]?.contains(id) ?? false)) (kind, id, null),
      ];
      await store.applySync(gone);
      for (final (kind, id, _) in gone) {
        _snapshot[kind]?.remove(id);
      }
      await _save();
    } else {
      _snapshot = {};
      await _save();
      await syncNow();
    }
  }

  /// Every id the household holds, by kind (asks from the start).
  Future<Map<String, Set<String>>> _fetchIds() async {
    final r = await _post('/h/$_household/sync', {'since': 0, 'changes': []}, auth: true);
    final out = <String, Set<String>>{};
    for (final rec in (r['records'] as List).cast<Map<String, Object?>>()) {
      if (rec['deleted'] == true) continue;
      out.putIfAbsent(rec['kind'] as String, () => {}).add(rec['id'] as String);
    }
    return out;
  }

  /// Leaves the household on this phone. The list stays here.
  Future<void> leave() async {
    stopLive();
    _household = null;
    _token = null;
    _cursor = 0;
    _snapshot = {};
    _lastSync = null;
    _error = null;
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------- sync

  /// Sends this phone's changes and takes the household's. Calls that come in
  /// while one is running are folded into one more run.
  Future<void> syncNow() async {
    if (!joined) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    _running = _run();
    try {
      await _running;
    } finally {
      _running = null;
    }
  }

  Future<void> _run() async {
    do {
      _again = false;
      _busy = true;
      notifyListeners();
      try {
        await _once();
        _error = null;
      } on SyncException catch (e) {
        _error = e.message;
      } catch (_) {
        _error = 'No connection to the household. Changes wait on this phone.';
      } finally {
        _busy = false;
        notifyListeners();
      }
    } while (_again && _error == null);
  }

  Future<void> _once() async {
    final current = store.syncRecords();
    final sent = _encodeAll(current);
    final changes = _changes(current);
    final r = await _post('/h/$_household/sync', {'since': _cursor, 'changes': changes, 'phone': _phone}, auth: true);

    // In step with what was sent (edits made while it was on its way stay changes).
    final snap = {
      for (final e in _snapshot.entries) e.key: {...e.value},
    };
    for (final c in changes) {
      final kind = c['kind'] as String, id = c['id'] as String;
      if (c['deleted'] == true) {
        snap[kind]?.remove(id);
      } else {
        snap.putIfAbsent(kind, () => {})[id] = sent[kind]![id]!;
      }
    }

    final incoming = <(String, String, Map<String, Object?>?)>[];
    for (final rec in (r['records'] as List).cast<Map<String, Object?>>()) {
      final kind = rec['kind'] as String, id = rec['id'] as String;
      final data = rec['deleted'] == true ? null : (rec['data'] as Map?)?.cast<String, Object?>();
      final mine = store.syncRecords()[kind]?[id];
      if (data == null ? mine == null : (mine != null && _same(mine, data))) continue;
      incoming.add((kind, id, data));
    }
    if (incoming.isNotEmpty) await store.applySync(incoming);
    // What arrived is in step, in this phone's own wording of it.
    final after = store.syncRecords();
    for (final (kind, id, _) in incoming) {
      final now = after[kind]?[id];
      if (now == null) {
        snap[kind]?.remove(id);
      } else {
        snap.putIfAbsent(kind, () => {})[id] = jsonEncode(now);
      }
    }
    _snapshot = snap;
    _cursor = (r['cursor'] as num).toInt();
    _lastSync = _clock();
    await _save();
  }

  /// What changed on this phone since the last sync, ready to send.
  List<Map<String, Object?>> _changes(Map<String, Map<String, Map<String, Object?>>> current) {
    final at = _clock().millisecondsSinceEpoch;
    final out = <Map<String, Object?>>[];
    for (final kind in current.keys) {
      final was = _snapshot[kind] ?? const {};
      for (final MapEntry(key: id, value: data) in current[kind]!.entries) {
        final enc = jsonEncode(data);
        final before = was[id];
        if (before == enc) continue;
        final change = <String, Object?>{'kind': kind, 'id': id, 'data': data, 'updatedAt': at};
        if (kind == 'items' && before != null) {
          final oldQty = ((jsonDecode(before) as Map)['quantity'] as num?)?.toDouble();
          final newQty = (data['quantity'] as num?)?.toDouble();
          if (oldQty != null && newQty != null) change['qtyDelta'] = newQty - oldQty;
        }
        out.add(change);
      }
      if (_appendOnly.contains(kind)) continue;
      for (final id in was.keys) {
        if (!current[kind]!.containsKey(id)) out.add({'kind': kind, 'id': id, 'deleted': true, 'updatedAt': at});
      }
    }
    return out;
  }

  static Map<String, Map<String, String>> _encodeAll(Map<String, Map<String, Map<String, Object?>>> r) => {
    for (final k in r.entries) k.key: {for (final e in k.value.entries) e.key: jsonEncode(e.value)},
  };

  // ------------------------------------------------------------------ live

  /// While the app is open: a change goes [pushDelay] after it is made, and
  /// the household's live line says the moment another phone changed
  /// something, so it shows here within a second or two. If the line is down
  /// the household is asked every 5 seconds instead (every 30 while it is up).
  void startLive() {
    if (_live || !joined) return;
    _live = true;
    store.addListener(_onStoreChanged);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final last = _lastSync;
      if (!_lineUp || last == null || _clock().difference(last) >= const Duration(seconds: 30)) syncNow();
    });
    _openLine();
    syncNow();
  }

  void stopLive() {
    if (!_live) return;
    _live = false;
    store.removeListener(_onStoreChanged);
    _pollTimer?.cancel();
    _pushTimer?.cancel();
    _closeLine();
  }

  void _onStoreChanged() {
    if (!joined || _busy) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDelay, syncNow);
  }

  Future<void> _openLine() async {
    if (!_live || !joined || _channel != null) return;
    final base = Uri.parse(server);
    final uri = base.replace(scheme: base.scheme == 'http' ? 'ws' : 'wss', path: '/h/$_household/live');
    final WebSocketChannel channel;
    try {
      channel = _connectLive(uri, {'authorization': 'Bearer $_token'});
      _channel = channel;
      await channel.ready;
    } catch (_) {
      _lineDown();
      return;
    }
    if (_channel != channel) return; // closed while opening
    _lineUp = true;
    _retries = 0;
    notifyListeners();
    _socketSub = channel.stream.listen(_onNote, onDone: _lineDown, onError: (Object _) => _lineDown());
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        channel.sink.add('ping');
      } catch (_) {}
    });
  }

  void _onNote(Object? message) {
    if (message is! String || message == 'pong') return;
    try {
      final note = (jsonDecode(message) as Map).cast<String, Object?>();
      final cursor = (note['cursor'] as num?)?.toInt() ?? 0;
      if (note['from'] == _phone || cursor <= _cursor) return;
      syncNow();
    } catch (_) {}
  }

  void _lineDown() {
    final wasUp = _lineUp;
    _shutLine();
    if (wasUp) notifyListeners();
    if (!_live) return;
    // Try again: 2, 4, 8 ... up to 60 seconds.
    final wait = Duration(seconds: min(60, 2 << min(_retries, 5)));
    _retries++;
    _reconnectTimer = Timer(wait, _openLine);
  }

  void _closeLine() {
    final wasUp = _lineUp;
    _shutLine();
    if (wasUp) notifyListeners();
  }

  void _shutLine() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _socketSub?.cancel();
    _socketSub = null;
    final c = _channel;
    _channel = null;
    _lineUp = false;
    if (c != null) {
      try {
        c.sink.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    stopLive();
    super.dispose();
  }

  // ------------------------------------------------------------------- http

  Future<Map<String, Object?>> _post(String path, Map<String, Object?> body, {bool auth = false}) async {
    final res = await _client
        .post(
          Uri.parse('$server$path'),
          headers: {'content-type': 'application/json', if (auth) 'authorization': 'Bearer $_token'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, Object?> data;
    try {
      data = (jsonDecode(res.body) as Map).cast<String, Object?>();
    } catch (_) {
      throw SyncException('The household server answered oddly (${res.statusCode}).');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw SyncException((data['error'] as String?) ?? 'This phone is not allowed in that household.');
    }
    if (res.statusCode >= 400) throw SyncException((data['error'] as String?) ?? 'The household server said no.');
    return data;
  }
}

/// Same JSON, counting 6 and 6.0 as the same number.
String _randomId() {
  final r = Random.secure();
  const a = 'abcdefghijkmnpqrstuvwxyz23456789';
  return List.generate(12, (_) => a[r.nextInt(a.length)]).join();
}

bool _same(Object? a, Object? b) {
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_same(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
