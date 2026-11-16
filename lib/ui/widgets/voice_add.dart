import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/household_store.dart';
import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/voice_parse.dart';
import 'common.dart';

/// Where spoken lines go.
enum VoiceTarget { shopping, stock }

/// Say it to add it: tap the microphone, say "two tins of tomatoes and a
/// dozen eggs", check the lines, add them to the list or to stock. Uses the
/// phone's own speech recognition (Australian English). Nothing is added
/// until "Add" is pressed.
Future<void> showVoiceAdd(BuildContext context, {VoiceTarget target = VoiceTarget.shopping, String? locationId}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceAdd(target: target, locationId: locationId),
    );

/// Adds spoken [lines] to the shopping list or to stock. Stock: an item with
/// the same name goes up (in its own unit where the measure converts); a new
/// name becomes a new item in [locationId]. Returns how many lines landed.
Future<int> addSpoken(
  HouseholdStore store,
  List<SpokenLine> lines,
  VoiceTarget target, {
  String locationId = 'pantry',
}) async {
  var n = 0;
  for (final l in lines) {
    if (target == VoiceTarget.shopping) {
      final unit = isMeasureUnit(l.unit) || const {'cup', 'tbsp', 'tsp'}.contains(l.unit) ? l.unit : '';
      await store.addShopping(name: l.name, quantity: l.quantity, unit: unit);
      n++;
      continue;
    }
    final have = store.itemByName(l.name);
    if (have != null) {
      final converted = l.unit.isEmpty || !isMeasureUnit(l.unit)
          ? (have.isMeasured ? l.quantity * have.packSize : l.quantity)
          : (convertUnits(l.quantity, l.unit, have.unit) ?? l.quantity);
      await store.adjust(have.id, converted);
    } else {
      final unit = isMeasureUnit(l.unit) ? (normaliseUnit(l.unit) == 'l' ? 'L' : l.unit) : l.unit;
      await store.addItem(name: l.name, locationId: locationId, quantity: l.quantity, unit: unit);
    }
    n++;
  }
  return n;
}

class _VoiceAdd extends StatefulWidget {
  const _VoiceAdd({required this.target, this.locationId});
  final VoiceTarget target;
  final String? locationId;

  @override
  State<_VoiceAdd> createState() => _VoiceAddState();
}

class _VoiceAddState extends State<_VoiceAdd> {
  final _speech = SpeechToText();
  late VoiceTarget _target = widget.target;
  String _heard = '';
  String? _problem;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    setState(() => _problem = null);
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (mounted) setState(() => _listening = s == 'listening');
      },
      onError: (e) {
        if (mounted) setState(() => _problem = 'Did not catch that (${e.errorMsg}). Tap the microphone to try again.');
      },
    );
    if (!ok) {
      if (mounted) setState(() => _problem = 'Speech is not available. Allow the microphone in the phone\'s settings.');
      return;
    }
    await _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _heard = r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_AU',
        partialResults: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _add(List<SpokenLine> lines) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await _speech.stop();
    final n = await addSpoken(store, lines, _target, locationId: widget.locationId ?? 'pantry');
    nav.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Added $n to ${_target == VoiceTarget.shopping ? 'the list' : 'stock'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lines = parseSpoken(_heard);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Say it to add it', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('e.g. "two tins of tomatoes and a dozen eggs"', style: text.bodyMedium),
          const SizedBox(height: 12),
          SegmentedButton<VoiceTarget>(
            segments: const [
              ButtonSegment(value: VoiceTarget.shopping, label: Text('Shopping list'), icon: Icon(Icons.shopping_cart)),
              ButtonSegment(value: VoiceTarget.stock, label: Text('Stock'), icon: Icon(Icons.kitchen)),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() => _target = s.first),
          ),
          const SizedBox(height: 16),
          Center(
            child: IconButton.filled(
              key: const ValueKey('voice-mic'),
              iconSize: 40,
              style: IconButton.styleFrom(
                backgroundColor: _listening ? scheme.error : scheme.primary,
                minimumSize: const Size(80, 80),
              ),
              tooltip: _listening ? 'Listening' : 'Speak',
              onPressed: _listening ? () => _speech.stop() : _listen,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _problem ?? (_listening ? 'Listening…' : (_heard.isEmpty ? 'Tap to speak' : '"$_heard"')),
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: _problem == null ? null : scheme.error),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final l in lines)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(l.name, style: text.titleSmall),
                      trailing: Text(
                        formatMeasure(l.quantity, l.unit),
                        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('voice-add'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => _add(lines),
              icon: const Icon(Icons.add),
              label: Text('Add ${lines.length} to ${_target == VoiceTarget.shopping ? 'the list' : 'stock'}'),
            ),
          ],
        ],
      ),
    );
  }
}
