import 'package:material_ui/material_ui.dart';

import '../../data/store_scope.dart';
import '../../logic/names.dart';
import '../../models/models.dart';
import 'pictures.dart';

/// "Is 'spring onoins' your Spring onions?" Yes teaches the name to the item
/// (both phones, for good); No makes sure it is never guessed again. Returns
/// true for yes, false for no, null when the question was dismissed.
Future<bool?> askSameThing(
  BuildContext context,
  String typed,
  StockItem item, {
  String? yesLabel,
  String? noLabel,
}) async {
  final store = StoreScope.read(context);
  final answer = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('same-thing'),
      icon: ProductPicture.of(item, size: 56),
      title: Text('Is "${typed.trim()}" your ${item.name}?'),
      content: const Text('The app remembers your answer on every phone in the household.'),
      actions: [
        TextButton(
          key: const ValueKey('same-thing-no'),
          onPressed: () => Navigator.pop(c, false),
          child: Text(noLabel ?? 'No, different'),
        ),
        FilledButton(
          key: const ValueKey('same-thing-yes'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(yesLabel ?? 'Yes, same thing'),
        ),
      ],
    ),
  );
  if (answer == true) await store.teachName(item.id, typed);
  if (answer == false) await store.rejectName(item.id, typed);
  return answer;
}

/// What [askAbout] decided.
sealed class NameChoice {
  const NameChoice();
}

/// Matched to a stock item.
class MatchedTo extends NameChoice {
  const MatchedTo(this.item);
  final StockItem item;
}

/// Something the household does not keep (or a new thing).
class NotKept extends NameChoice {
  const NotKept();
}

/// Choose which stock item [name] is, with a search box: the closest names
/// first. Picking one teaches the name to it; "Not something we keep" (or,
/// with [current], "Not this") rejects the current match. Null when closed.
Future<NameChoice?> pickStockFor(BuildContext context, String name, {StockItem? current}) async {
  final store = StoreScope.read(context);
  final choice = await showModalBottomSheet<NameChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _Picker(name: name, current: current),
    ),
  );
  switch (choice) {
    case MatchedTo(:final item):
      await store.teachName(item.id, name);
    case NotKept():
      if (current != null) await store.rejectName(current.id, name);
    case null:
      break;
  }
  return choice;
}

class _Picker extends StatefulWidget {
  const _Picker({required this.name, this.current});
  final String name;
  final StockItem? current;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final q = _query.trim();
    // Closest to what was typed first, then A to Z.
    int rank(StockItem i) => compareNames(q.isEmpty ? widget.name : q, i.name)?.rank ?? 99;
    final items =
        [
          for (final i in store.items)
            if (q.isEmpty || i.name.toLowerCase().contains(q.toLowerCase()) || rank(i) < 99) i,
        ]..sort((a, b) {
          final r = rank(a).compareTo(rank(b));
          return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('What is "${widget.name}"?', style: text.titleLarge, textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('pick-stock-search'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search what you keep'),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                key: const ValueKey('pick-not-kept'),
                leading: const Icon(Icons.block),
                title: Text(widget.current == null ? 'Not something we keep' : 'Not ${widget.current!.name}'),
                onTap: () => Navigator.pop(context, const NotKept()),
              ),
              for (final i in items)
                ListTile(
                  key: ValueKey('pick-${i.id}'),
                  leading: ProductPicture.of(i, size: 36),
                  title: Text(i.name),
                  subtitle: i.aliases.isEmpty ? null : Text('also ${i.aliases.join(', ')}'),
                  trailing: i.id == widget.current?.id ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, MatchedTo(i)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
