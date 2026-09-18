import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../../../data/repositories/session_repository.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../profile/providers/profile_context_provider.dart';
import '../../reminders/providers/reminder_prefs_provider.dart';

/// Settings (Stage 9.3): what is collected, JSON export, full deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final sessions = await ref
        .read(sessionRepositoryProvider)
        .loadLocalSessions();
    final checkIns = ref.read(checkInProvider);
    final profile = ref.read(profileContextProvider);
    final data = {
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'check_ins': checkIns.map((c) => c.toJson()).toList(),
      'demographics': profile.demographics.toJson(),
      'monitoring_profile': profile.monitoringProfileType?.name,
      'parkinson_context': profile.parkinsonContext.toJson(),
    };
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your data (JSON)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(data),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This clears buffered sessions and check-ins on this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(sessionRepositoryProvider).clearLocalData();
      ref.read(checkInProvider.notifier).clear();
      ref.invalidate(localSessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local data deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Theme'),
            subtitle: const Text('Dark is calmer for patients; light/day also available'),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeModeProvider),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
              onChanged: (m) {
                if (m != null) ref.read(themeModeProvider.notifier).setMode(m);
              },
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('What is collected'),
              subtitle: Text(
                'Keystroke timing, derived hand position, tapping-task '
                'mechanics, session metadata, and details you choose to '
                'provide. Typed text is never stored. Raw key identity is '
                'discarded at capture.',
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Daily reminder'),
              subtitle: Text(
                ref.watch(reminderPrefsProvider).enabled
                    ? 'Nudge around ${ref.watch(reminderPrefsProvider).hour}:00 if you have not typed yet'
                    : 'Turn on for a gentle daily typing nudge (on-device only)',
              ),
              value: ref.watch(reminderPrefsProvider).enabled,
              onChanged: (v) =>
                  ref.read(reminderPrefsProvider.notifier).setEnabled(v),
            ),
          ),
          if (ref.watch(reminderPrefsProvider).enabled)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Reminder time'),
                subtitle: Text(
                  '${ref.watch(reminderPrefsProvider).hour}:00 local time',
                ),
                trailing: DropdownButton<int>(
                  value: ref.watch(reminderPrefsProvider).hour,
                  items: [
                    for (var h = 7; h <= 22; h++)
                      DropdownMenuItem(value: h, child: Text('$h:00')),
                  ],
                  onChanged: (h) {
                    if (h != null) {
                      ref.read(reminderPrefsProvider.notifier).setHour(h);
                    }
                  },
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export my data (JSON)'),
              onTap: () => _export(context, ref),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete all local data'),
              onTap: () => _deleteAll(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
