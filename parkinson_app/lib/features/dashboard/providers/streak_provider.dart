import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/session_repository.dart';

/// Compute streak: consecutive days (local) with at least one
/// screening session, counting backwards from today.
/// Today with no session yet does not break the streak — it is
/// just not counted until a session appears.
int computeStreak(List<DateTime> screeningDates, DateTime today) {
  final days = screeningDates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();
  var cursor = DateTime(today.year, today.month, today.day);
  var streak = 0;
  // If today has no session, start from yesterday for streak count
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Milestone thresholds that trigger a congratulatory banner.
/// Shown once per threshold via a simple "last seen" guard in UI.
const milestoneThresholds = [7, 14, 30, 50, 100];

int? nextMilestone(int screeningCount) {
  for (final m in milestoneThresholds) {
    if (screeningCount < m) return m;
  }
  return null;
}

int? latestMilestoneHit(int screeningCount) {
  int? hit;
  for (final m in milestoneThresholds) {
    if (screeningCount >= m) hit = m;
  }
  return hit;
}

final streakProvider = Provider<int>((ref) {
  final sessions = ref.watch(localSessionsProvider).valueOrNull ?? [];
  final dates = sessions
      .where((s) => !s.isFamiliarization)
      .map((s) => s.startTime.toLocal())
      .toList();
  return computeStreak(dates, DateTime.now());
});

final screeningCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(localSessionsProvider).valueOrNull ?? [];
  return sessions.where((s) => !s.isFamiliarization).length;
});
