import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { real, demo }

class AppModeState {
  final AppMode mode;
  final bool hasCompletedOnboarding;
  const AppModeState({
    this.mode = AppMode.real,
    this.hasCompletedOnboarding = false,
  });

  bool get isDemo => mode == AppMode.demo;
  AppModeState copyWith({AppMode? mode, bool? hasCompletedOnboarding}) =>
      AppModeState(
        mode: mode ?? this.mode,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      );
}

class AppModeNotifier extends StateNotifier<AppModeState> {
  static const _keyMode = 'app_mode_v1';
  static const _keyOnboarded = 'app_has_onboarded_v1';
  AppModeNotifier() : super(const AppModeState()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt(_keyMode) ?? 0;
    final onboarded = p.getBool(_keyOnboarded) ?? false;
    state = AppModeState(
      mode: AppMode.values[idx.clamp(0, AppMode.values.length - 1)],
      hasCompletedOnboarding: onboarded,
    );
  }

  Future<void> enterDemo() async {
    state = state.copyWith(mode: AppMode.demo);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyMode, AppMode.demo.index);
  }

  Future<void> exitDemo() async {
    state = state.copyWith(mode: AppMode.real);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyMode, AppMode.real.index);
  }

  Future<void> setOnboarded(bool v) async {
    state = state.copyWith(hasCompletedOnboarding: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyOnboarded, v);
  }

  Future<void> resetDemo() async {
    // clears demo flag + onboarding so wizard re-runs
    state = const AppModeState(
      mode: AppMode.demo,
      hasCompletedOnboarding: false,
    );
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyMode, AppMode.demo.index);
    await p.setBool(_keyOnboarded, false);
  }
}

final appModeProvider = StateNotifierProvider<AppModeNotifier, AppModeState>(
  (ref) => AppModeNotifier(),
);
