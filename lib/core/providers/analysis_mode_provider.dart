import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnalysisMode { layer1, layer2 }

extension AnalysisModeX on AnalysisMode {
  String get label => switch (this) {
        AnalysisMode.layer1 => 'Quick Analysis',
        AnalysisMode.layer2 => 'Personal Monitoring',
      };
  String get badge => switch (this) {
        AnalysisMode.layer1 => 'LAYER 1',
        AnalysisMode.layer2 => 'LAYER 2',
      };
  String get subtitle => switch (this) {
        AnalysisMode.layer1 => '1–2 sessions, population comparison',
        AnalysisMode.layer2 => '10 sessions across 5 days, your baseline',
      };
}

class AnalysisModeNotifier extends StateNotifier<AnalysisMode?> {
  static const _key = 'analysis_mode_v1';
  AnalysisModeNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt(_key);
    if (idx != null && idx >= 0 && idx < AnalysisMode.values.length) {
      state = AnalysisMode.values[idx];
    }
  }

  Future<void> setMode(AnalysisMode mode) async {
    state = mode;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key, mode.index);
  }

  Future<void> clear() async {
    state = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}

final analysisModeProvider =
    StateNotifierProvider<AnalysisModeNotifier, AnalysisMode?>((ref) => AnalysisModeNotifier());
