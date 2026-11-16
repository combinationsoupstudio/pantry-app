import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/backup.dart';
import '../../data/store_scope.dart';
import '../../data/sync_service.dart';
import '../widgets/common.dart';

/// "Synced 12 s ago", "Synced 3 min ago".
String syncedAgo(DateTime? last, DateTime now) {
  if (last == null) return 'Not synced yet';
  final s = now.difference(last).inSeconds;
  if (s < 5) return 'Synced just now';
  if (s < 60) return 'Synced $s s ago';
  if (s < 3600) return 'Synced ${s ~/ 60} min ago';
  if (s < 86400) return 'Synced ${s ~/ 3600} h ago';
  return 'Synced ${s ~/ 86400} days ago';
}

/// The cloud on Home: shows how sync is going; tap to sync now.
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.instance;
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final IconData icon;
        final String tip;
        if (!sync.joined) {
          icon = Icons.cloud_outlined;
          tip = 'Share with the household';
        } else if (sync.error != null) {
          icon = Icons.cloud_off_outlined;
          tip = sync.error!;
        } else {
          icon = Icons.cloud_done_outlined;
          tip = syncedAgo(sync.lastSync, DateTime.now());
        }
        return IconButton(
          key: const ValueKey('sync-button'),
          tooltip: tip,
          icon: sync.busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon),
          onPressed: () async {
            if (!sync.joined) {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HouseholdPage()));
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            await sync.syncNow();
            messenger.showSnackBar(SnackBar(content: Text(sync.error ?? 'In step with the household')));
          },
        );
      },
    );
  }
}

/// Settings > Household: start one, join one, sync, add a phone, leave.
class HouseholdPage extends StatelessWidget {
  const HouseholdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Household')),
      body: sync == null
          ? const Center(child: Text('Sync is not running on this phone.'))
          : ListenableBuilder(
              listenable: sync,
              builder: (context, _) => sync.joined ? _Joined(sync) : _NotJoined(sync),
            ),
    );
  }
}

class _NotJoined extends StatelessWidget {
  const _NotJoined(this.sync);
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Share one list between phones. A change on one phone shows on the others '
          'within a few seconds while the app is open, and the next time it opens otherwise.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('household-start'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Start a household with this phone\'s list'),
          onPressed: sync.busy ? null : () => _start(context),
        ),
        const SizedBox(height: 8),
        const Text('Do this on ONE phone. It gives you a code for the next phone.'),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const ValueKey('household-join'),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Join with a code'),
          onPressed: sync.busy ? null : () => _join(context),
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final code = await sync.start();
      if (context.mounted) await _showCode(context, code);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_why(e))));
    }
  }

  Future<void> _join(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final result = await showDialog<(String, JoinMode)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a household'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('join-code'),
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code from the other phone', hintText: 'ABCD2345-123456'),
            ),
            const SizedBox(height: 16),
            Text(
              store.items.isEmpty
                  ? 'This phone has nothing on it yet.'
                  : 'This phone has ${store.items.length} things on it.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (store.items.isNotEmpty)
            TextButton(
              key: const ValueKey('join-add-mine'),
              onPressed: () => Navigator.pop(context, (controller.text, JoinMode.addMine)),
              child: const Text('Join and add mine'),
            ),
          FilledButton(
            key: const ValueKey('join-use-household'),
            onPressed: () => Navigator.pop(context, (controller.text, JoinMode.useHousehold)),
            child: Text(store.items.isEmpty ? 'Join' : 'Join, use theirs'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final (code, mode) = result;
    try {
      String? saved;
      if (mode == JoinMode.useHousehold && store.items.isNotEmpty) {
        // This phone's list goes, so it is kept in a file first.
        final now = DateTime.now();
        final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/backups')
          ..createSync(recursive: true);
        final file = File('${dir.path}/before-joining-${backupFileName(now)}');
        await file.writeAsString(makeBackup(store, now: now));
        saved = file.path;
      }
      await sync.join(code, mode);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sync.error ??
                (saved == null ? 'Joined the household' : 'Joined. This phone\'s old list is saved in a backup file.'),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_why(e))));
    }
  }
}

class _Joined extends StatelessWidget {
  const _Joined(this.sync);
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    final waiting = sync.waiting;
    return ListView(
      children: [
        ListTile(
          leading: Icon(sync.error == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
          title: Text('Household ${sync.household}'),
          subtitle: Text(
            [
              sync.error ?? syncedAgo(sync.lastSync, DateTime.now()),
              if (waiting > 0) '$waiting change${waiting == 1 ? '' : 's'} waiting to go',
            ].join('\n'),
          ),
        ),
        ListTile(
          key: const ValueKey('sync-now'),
          leading: sync.busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          title: const Text('Sync now'),
          subtitle: const Text('It also syncs by itself every few seconds while the app is open'),
          onTap: sync.busy ? null : sync.syncNow,
        ),
        const SectionHeader('Phones'),
        ListTile(
          key: const ValueKey('add-phone'),
          leading: const Icon(Icons.phonelink_ring_outlined),
          title: const Text('Add another phone'),
          subtitle: const Text('Gives a code that works once, for 48 hours'),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final code = await sync.invite();
              if (context.mounted) await _showCode(context, code);
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(_why(e))));
            }
          },
        ),
        ListTile(
          key: const ValueKey('leave-household'),
          leading: const Icon(Icons.logout),
          title: const Text('Stop sharing on this phone'),
          subtitle: const Text('The list stays on this phone; it just stops syncing'),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Stop sharing?'),
                content: const Text('This phone keeps its list but stops syncing. You need a new code to join again.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop sharing')),
                ],
              ),
            );
            if (ok == true) await sync.leave();
          },
        ),
      ],
    );
  }
}

Future<void> _showCode(BuildContext context, String code) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Code for the other phone'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(code, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('On the other phone: Settings > Household > Join with a code. It works once, for 48 hours.'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Clipboard.setData(ClipboardData(text: code)),
        child: const Text('Copy'),
      ),
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
    ],
  ),
);

String _why(Object e) {
  if (e is SyncException) {
    if (e.message == 'wrong or old code') return 'That code is wrong or already used. Ask for a new one.';
    if (e.message == 'no such household') return 'No household has that code.';
    return e.message;
  }
  return 'No connection to the household server. Try again with signal.';
}
