import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeMode with persistence (calm dark default, light/day toggle).
/// Stored as int index in ThemeMode.values.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode_v1';
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_key);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      state = ThemeMode.values[idx];
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
        (ref) => ThemeModeNotifier());
