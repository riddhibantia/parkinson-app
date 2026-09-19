import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user_profile.dart';

/// Onboarding-collected context (Stages 1.7 / 1.8).
/// Demographics + monitoring profile are stored once in the user profile;
/// never duplicated into every session document.
class ProfileContextState {
  final DemographicContext demographics;
  final MonitoringProfileType? monitoringProfileType;
  final ParkinsonContext parkinsonContext;

  const ProfileContextState({
    this.demographics = const DemographicContext(),
    this.monitoringProfileType,
    this.parkinsonContext = const ParkinsonContext(),
  });

  ProfileContextState copyWith({
    DemographicContext? demographics,
    MonitoringProfileType? monitoringProfileType,
    ParkinsonContext? parkinsonContext,
  }) {
    return ProfileContextState(
      demographics: demographics ?? this.demographics,
      monitoringProfileType:
          monitoringProfileType ?? this.monitoringProfileType,
      parkinsonContext: parkinsonContext ?? this.parkinsonContext,
    );
  }
}

class ProfileContextNotifier extends StateNotifier<ProfileContextState> {
  ProfileContextNotifier() : super(const ProfileContextState());

  void setDemographics(DemographicContext demographics) {
    state = state.copyWith(demographics: demographics);
  }

  void setMonitoringProfile(MonitoringProfileType? type) {
    state = state.copyWith(monitoringProfileType: type);
  }

  void setParkinsonContext(ParkinsonContext context) {
    state = state.copyWith(parkinsonContext: context);
  }
}

final profileContextProvider =
    StateNotifierProvider<ProfileContextNotifier, ProfileContextState>(
  (ref) => ProfileContextNotifier(),
);
