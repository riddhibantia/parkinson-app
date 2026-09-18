import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/features/dashboard/providers/streak_provider.dart';

void main() {
  group('computeStreak', () {
    test('empty -> 0', () {
      expect(computeStreak([], DateTime(2026, 5, 13)), 0);
    });
    test('consecutive days ending today', () {
      final dates = [
        DateTime(2026, 5, 11, 10),
        DateTime(2026, 5, 12, 9),
        DateTime(2026, 5, 13, 8),
      ];
      expect(computeStreak(dates, DateTime(2026, 5, 13)), 3);
    });
    test('today missing still counts yesterday streak', () {
      final dates = [DateTime(2026, 5, 11), DateTime(2026, 5, 12)];
      expect(computeStreak(dates, DateTime(2026, 5, 13)), 2);
    });
    test('gap breaks streak', () {
      final dates = [DateTime(2026, 5, 10), DateTime(2026, 5, 13)];
      expect(computeStreak(dates, DateTime(2026, 5, 13)), 1);
    });
    test('multiple sessions same day count once', () {
      final dates = [
        DateTime(2026, 5, 13, 8),
        DateTime(2026, 5, 13, 20),
        DateTime(2026, 5, 12),
      ];
      expect(computeStreak(dates, DateTime(2026, 5, 13)), 2);
    });
  });

  test('milestones', () {
    expect(latestMilestoneHit(30), 30);
    expect(latestMilestoneHit(29), 14);
    expect(nextMilestone(30), 50);
    expect(nextMilestone(100), isNull);
  });
}
