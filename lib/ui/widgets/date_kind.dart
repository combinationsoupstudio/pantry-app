import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';

/// Use by | Best before (v0.18, #36). Every date is one or the other:
/// picking one unpicks the other.
class DateKindSwitch extends StatelessWidget {
  const DateKindSwitch({super.key, required this.value, required this.onChanged});

  final DateKind value;
  final ValueChanged<DateKind> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<DateKind>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: DateKind.useBy,
          icon: Icon(Icons.health_and_safety_outlined),
          label: Text('Use by', key: ValueKey('kind-useBy')),
        ),
        ButtonSegment(
          value: DateKind.bestBefore,
          icon: Icon(Icons.star_outline),
          label: Text('Best before', key: ValueKey('kind-bestBefore')),
        ),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    ),
  );
}

/// One line under the switch saying what the chosen kind means.
String dateKindHint(DateKind kind) => kind == DateKind.useBy
    ? 'Safety date: past it, throw it out.'
    : 'Quality date: past it, usually fine if it looks and smells right.';

/// Picks a date and its kind together: the switch, then the calendar.
/// Returns null when closed without a pick.
Future<(DateTime, DateKind)?> showDateAndKindPicker(
  BuildContext context, {
  required DateTime initial,
  required DateKind kind,
}) {
  return showModalBottomSheet<(DateTime, DateKind)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DateAndKind(initial: initial, kind: kind),
  );
}

class _DateAndKind extends StatefulWidget {
  const _DateAndKind({required this.initial, required this.kind});
  final DateTime initial;
  final DateKind kind;

  @override
  State<_DateAndKind> createState() => _DateAndKindState();
}

class _DateAndKindState extends State<_DateAndKind> {
  late DateKind _kind = widget.kind;
  late DateTime _day = widget.initial;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateKindSwitch(value: _kind, onChanged: (k) => setState(() => _kind = k)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(dateKindHint(_kind), style: text.bodySmall),
          ),
          CalendarDatePicker(
            initialDate: _day,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 10),
            onDateChanged: (d) => setState(() => _day = d),
          ),
          FilledButton(
            key: const ValueKey('date-kind-done'),
            onPressed: () => Navigator.of(context).pop((DateTime(_day.year, _day.month, _day.day), _kind)),
            child: Text('${_kind.label} ${_day.day}/${_day.month}/${_day.year}'),
          ),
        ],
      ),
    );
  }
}
