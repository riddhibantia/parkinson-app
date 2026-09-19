import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/analysis_mode_provider.dart';
import '../../../data/repositories/session_repository.dart';

/// Session history (Stage 7.4 shell). Live backend stream when ready,
/// otherwise the on-device buffer. Practice sessions always labelled
/// Practice — never given a health status.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessionRepositoryProvider);
    final mode = ref.watch(analysisModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(mode == AnalysisMode.layer1 ? 'Quick Analysis History' : mode == AnalysisMode.layer2 ? 'Monitoring History' : 'History')),
      body: StreamBuilder(
        stream: repo.watchSessions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!.where((s) => !s.isFamiliarization).toList();
          if (sessions.isEmpty) {
            return Center(child: Text(mode == AnalysisMode.layer2 ? 'No monitoring sessions yet.' : 'No sessions yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              final label = mode == AnalysisMode.layer2 ? 'Monitoring Session ${i + 1}' : 'Quick Analysis Session ${i + 1}';
              return Card(
                child: ListTile(
                  leading: Icon(mode == AnalysisMode.layer2 ? Icons.timeline_outlined : Icons.science_outlined),
                  title: Text(label),
                  subtitle: Text('${s.startTime.toLocal().toString().substring(0, 16)} · ${s.totalKeystrokes} keys · ${s.deviceId}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (mode == AnalysisMode.layer2) {
                      context.push('/session/layer2/${s.sessionId}', extra: s);
                    } else if (mode == AnalysisMode.layer1) {
                      context.push('/insights/layer1');
                    } else {
                      context.push('/insights/layer1');
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
