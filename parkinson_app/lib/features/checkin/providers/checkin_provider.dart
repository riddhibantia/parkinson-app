import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_profile.dart';

/// Daily check-in history (Stage 1.9). Kept as its own time series,
/// separate from typing/motor ML inputs. Backend sync lands in Stage 6.
class CheckInNotifier extends StateNotifier<List<SymptomCheckIn>> {
  CheckInNotifier() : super(const []);

  void add(SymptomCheckIn checkIn) {
    state = [...state, checkIn];
  }

  /// Delete all on-device check-ins (Settings, Stage 9.3).
  void clear() {
    state = const [];
  }

  SymptomCheckIn? get latest => state.isEmpty ? null : state.last;
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, List<SymptomCheckIn>>(
  (ref) => CheckInNotifier(),
);
