import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-app reminder preferences (Stage 8) — no OS scheduling, no Blaze.
///
/// Stores a simple daily nudge preference on-device. The app surfaces a
/// gentle "time to type" hint on the dashboard when the preferred hour
/// has passed and no session was recorded today. This avoids any
/// Cloud Messaging / Cloud Scheduler dependency while still supporting
/// the adherence loop the plan calls for.
class ReminderPrefs {
  final bool enabled;
  final int hour; // 0-23 local hour

  const ReminderPrefs({this.enabled = false, this.hour = 19});

  Map<String, dynamic> toJson() => {'enabled': enabled, 'hour': hour};
}

class ReminderPrefsNotifier extends StateNotifier<ReminderPrefs> {
  static const _keyEnabled = 'reminder_enabled_v1';
  static const _keyHour = 'reminder_hour_v1';
  ReminderPrefsNotifier() : super(const ReminderPrefs()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final hour = prefs.getInt(_keyHour) ?? 19;
    state = ReminderPrefs(enabled: enabled, hour: hour.clamp(0, 23));
  }

  Future<void> setEnabled(bool value) async {
    state = ReminderPrefs(enabled: value, hour: state.hour);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  Future<void> setHour(int hour) async {
    final clamped = hour.clamp(0, 23);
    state = ReminderPrefs(enabled: state.enabled, hour: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, clamped);
  }

  /// Human-readable next-nudge hint for the dashboard.
  String nextHint({required DateTime now, required bool typedToday}) {
    if (!state.enabled)
      return 'Reminders off — enable in Settings to stay consistent.';
    if (typedToday)
      return 'Nice — you typed today. See you tomorrow around ${state.hour}:00.';
    if (now.hour >= state.hour)
      return 'Gentle nudge: time for your daily typing check-in.';
    return 'Reminder set for today around ${state.hour}:00.';
  }
}

final reminderPrefsProvider =
    StateNotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(
      (ref) => ReminderPrefsNotifier(),
    );
