import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/session_repository.dart';

/// Session history (Stage 7.4 shell). Live backend stream when ready,
/// otherwise the on-device buffer. Practice sessions always labelled
/// Practice — never given a health status.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder(
        stream: repo.watchSessions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return const Center(
              child: Text('No sessions yet.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              return Card(
                child: ListTile(
                  leading: Icon(
                    s.isFamiliarization
                        ? Icons.school_outlined
                        : Icons.keyboard_outlined,
                  ),
                  title: Text(
                    '${s.mode} · ${s.isFamiliarization ? 'Practice' : 'Screening'}',
                  ),
                  subtitle: Text(
                    '${s.startTime.toLocal().toString().substring(0, 16)} · '
                    '${s.totalKeystrokes} keys · ${s.deviceId}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
