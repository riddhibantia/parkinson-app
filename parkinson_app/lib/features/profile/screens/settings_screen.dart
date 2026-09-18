import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/session_repository.dart';
import '../../checkin/providers/checkin_provider.dart';
import '../../profile/providers/profile_context_provider.dart';

/// Settings (Stage 9.3): what is collected, JSON export, full deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final sessions =
        await ref.read(sessionRepositoryProvider).loadLocalSessions();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local data deleted.')),
        );
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
