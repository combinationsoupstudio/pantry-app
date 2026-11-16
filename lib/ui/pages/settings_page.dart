import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../data/household_store.dart';
import '../../data/store_scope.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader('Who is using this phone'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [for (final m in householdMembers) ButtonSegment(value: m, label: Text(m))],
              selected: {store.user},
              onSelectionChanged: (s) => store.setUser(s.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Changes are signed with this name in the history.'),
          ),
          const SectionHeader('Stock list'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import from CSV'),
            subtitle: const Text('Paste rows: name, location, quantity, unit, target'),
            onTap: () => _import(context),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Copy stock list as CSV'),
            subtitle: const Text('A backup you can paste anywhere'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: store.exportCsv()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
              }
            },
          ),
          const SectionHeader('Locations'),
          for (final l in store.locations)
            ListTile(
              dense: true,
              title: Text(l.name),
              trailing: Text(l.kind == LocationKind.pantry ? 'Pantry page' : 'Storage page'),
            ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Add a location'),
            onTap: () => _addLocation(context),
          ),
          const SectionHeader('About'),
          const ListTile(
            title: Text('Pantry'),
            subtitle: Text('Stock is kept on this phone for now. Syncing between phones comes in a later release.'),
          ),
          const ListTile(
            title: Text('Product data'),
            subtitle: Text(
              'Product names, pack sizes and pictures come from Open Food Facts (openfoodfacts.org), the free open '
              'food database: data under the Open Database Licence, pictures under Creative Commons BY-SA 3.0. '
              'Only a barcode number or the words you search for are sent. Pictures are downloaded once and kept '
              'on this phone.',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import stock'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'name,location,quantity,unit,target\nRice,Pantry,2,kg,5'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final r = await StoreScope.read(context).importCsv(controller.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${r.added} added, ${r.updated} updated${r.skipped > 0 ? ', ${r.skipped} lines skipped' : ''}',
            ),
          ),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _addLocation(BuildContext context) async {
    final controller = TextEditingController();
    var kind = LocationKind.storage;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Add a location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<LocationKind>(
                segments: const [
                  ButtonSegment(value: LocationKind.pantry, label: Text('Pantry page')),
                  ButtonSegment(value: LocationKind.storage, label: Text('Storage page')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty && context.mounted) {
      await StoreScope.read(context).addLocation(controller.text, kind);
    }
    controller.dispose();
  }
}
