import 'package:material_ui/material_ui.dart';

import '../../data/backup.dart';

import 'package:flutter/services.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/household_store.dart';
import '../../data/picture_finder.dart';
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
          const SectionHeader('Backup'),
          ListTile(
            key: const ValueKey('backup-now'),
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Back up now'),
            subtitle: const Text('Everything, with your photos, in one file. Save it to Google Drive.'),
            onTap: () => _backup(context),
          ),
          ListTile(
            key: const ValueKey('restore-backup'),
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restore from a backup'),
            subtitle: const Text('Replaces what is on this phone with the backup'),
            onTap: () => _restore(context),
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
          ListTile(
            key: const ValueKey('find-pictures-again'),
            leading: const Icon(Icons.image_search),
            title: const Text('Find pictures again'),
            subtitle: const Text('Looks again for items still showing a letter. Pictures appear over a few minutes.'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final n = await StoreScope.read(context).retryPictures();
              PictureFinder.instance?.nudge();
              messenger.showSnackBar(
                SnackBar(content: Text(n == 0 ? 'Already looking for every picture' : 'Looking again for $n pictures')),
              );
            },
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

/// Writes the backup file and opens the phone's share sheet to save it
/// (Google Drive, email to yourself, Files).
Future<void> _backup(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final now = DateTime.now();
    final dir = Directory('${(await getTemporaryDirectory()).path}/backups')..createSync(recursive: true);
    final file = File('${dir.path}/${backupFileName(now)}');
    await file.writeAsString(makeBackup(store, now: now));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Pantry backup ${now.day}/${now.month}/${now.year}',
        text: 'Pantry app backup. Keep this file; Settings > Restore brings it back.',
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
  }
}

/// Picks a backup file and, after a clear warning, restores it.
Future<void> _restore(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFile(dialogTitle: 'Pick a pantry backup');
  if (picked == null || !context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Restore this backup?'),
      content: Text(
        'Everything on this phone (${store.items.length} items, the list, recipes and prices) is replaced by '
        '${picked.name}. Back up first if you are not sure.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace with backup')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final text = await picked.xFile.readAsString();
    final docs = await getApplicationDocumentsDirectory();
    final r = await restoreBackup(store, text, Directory('${docs.path}/photos'));
    messenger.showSnackBar(SnackBar(content: Text('Restored ${r.items} items and ${r.photos} photos')));
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
  }
}
