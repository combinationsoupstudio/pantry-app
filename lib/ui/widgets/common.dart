import 'package:material_ui/material_ui.dart';

/// A heading that reads as a heading: small capitals in the brand colour,
/// with an optional count and an action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A figure on a card. [tone] colours it when it needs attention.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.onTap, this.tone});
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Null for neutral, or a status colour pair (colour, container).
  final (Color, Color)? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = tone?.$1 ?? scheme.primary;
    final bg = tone?.$2 ?? scheme.primaryContainer;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 18, color: fg),
                ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: tone == null ? null : fg),
                ),
              ),
              Text(label, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// "3 Nov", "today", "yesterday".
String friendlyDate(DateTime when, DateTime now) {
  final d = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff == -1) return 'yesterday';
  if (diff == 1) return 'tomorrow';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${when.day} ${months[when.month - 1]}';
}

String friendlyTime(DateTime when, DateTime now) {
  final h = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final m = when.minute.toString().padLeft(2, '0');
  final ampm = when.hour < 12 ? 'am' : 'pm';
  return '${friendlyDate(when, now)} $h:$m$ampm';
}

/// Bottom padding for a bottom sheet: clear of the keyboard when it is up,
/// and of the phone's own buttons (the navigation bar) when it is not.
double sheetBottom(BuildContext context, {double extra = 16}) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  final bar = MediaQuery.viewPaddingOf(context).bottom;
  return (keyboard > bar ? keyboard : bar) + extra;
}
