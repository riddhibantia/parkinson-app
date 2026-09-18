import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_profile.dart';

/// Familiarization state (Stage 1.6 / 2.2).
/// Practice sessions are excluded from all screening/baseline scoring;
/// this provider only tracks the readiness gate.
class FamiliarizationState {
  final TypingExperienceLevel? experienceLevel;
  final int completedPracticeSessions;
  final bool screeningReady;

  const FamiliarizationState({
    this.experienceLevel,
    this.completedPracticeSessions = 0,
    this.screeningReady = false,
  });

  int get requiredSessions =>
      experienceLevel?.requiredPracticeSessions ?? 1;

  FamiliarizationState copyWith({
    TypingExperienceLevel? experienceLevel,
    int? completedPracticeSessions,
    bool? screeningReady,
  }) {
    return FamiliarizationState(
      experienceLevel: experienceLevel ?? this.experienceLevel,
      completedPracticeSessions:
          completedPracticeSessions ?? this.completedPracticeSessions,
      screeningReady: screeningReady ?? this.screeningReady,
    );
  }
}

class FamiliarizationNotifier extends StateNotifier<FamiliarizationState> {
  FamiliarizationNotifier() : super(const FamiliarizationState());

  void setExperienceLevel(TypingExperienceLevel level) {
    state = state.copyWith(experienceLevel: level);
  }

  void recordPracticeSession({required bool stable}) {
    final completed = state.completedPracticeSessions + 1;
    final required = state.requiredSessions;
    final ready = completed >= required && stable;
    state = state.copyWith(
      completedPracticeSessions: completed,
      screeningReady: ready,
    );
  }
}

final familiarizationProvider =
    StateNotifierProvider<FamiliarizationNotifier, FamiliarizationState>(
  (ref) => FamiliarizationNotifier(),
);
