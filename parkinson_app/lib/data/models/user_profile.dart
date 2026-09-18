/// Typing experience level (Stage 1.6).
/// Used ONLY to determine familiarization requirements.
/// Never used as an ML or diagnostic feature.
enum TypingExperienceLevel {
  regular,
  occasional,
  notFamiliar,
}

extension TypingExperienceLevelX on TypingExperienceLevel {
  String get label {
    switch (this) {
      case TypingExperienceLevel.regular:
        return 'Regular typist';
      case TypingExperienceLevel.occasional:
        return 'Occasional typist';
      case TypingExperienceLevel.notFamiliar:
        return 'Not familiar';
    }
  }

  String get description {
    switch (this) {
      case TypingExperienceLevel.regular:
        return 'Types frequently / comfortable with a physical keyboard';
      case TypingExperienceLevel.occasional:
        return 'Types sometimes but not regularly';
      case TypingExperienceLevel.notFamiliar:
        return 'Rarely types / not comfortable with a physical keyboard';
    }
  }

  /// Required practice sessions before the readiness gate.
  int get requiredPracticeSessions {
    switch (this) {
      case TypingExperienceLevel.regular:
        return 1;
      case TypingExperienceLevel.occasional:
        return 1;
      case TypingExperienceLevel.notFamiliar:
        return 2;
    }
  }
}

/// Sex/gender as recorded by the source (Stage 1.7 / 3.4).
/// Never inferred from typing data. `preferNotToSay` / `unknown` must
/// never block the typing pipeline.
enum SexGender {
  male,
  female,
  preferNotToSay,
  unknown,
}

extension SexGenderX on SexGender {
  String get label {
    switch (this) {
      case SexGender.male:
        return 'Male';
      case SexGender.female:
        return 'Female';
      case SexGender.preferNotToSay:
        return 'Prefer not to say';
      case SexGender.unknown:
        return 'Unknown';
    }
  }

  String get wireValue {
    switch (this) {
      case SexGender.male:
        return 'male';
      case SexGender.female:
        return 'female';
      case SexGender.preferNotToSay:
        return 'prefer_not_to_say';
      case SexGender.unknown:
        return 'unknown';
    }
  }
}

/// Subject-level demographic context (Stage 1.7).
/// Covariate for reference selection/reporting only — never a typing
/// feature, never a dynamic Layer 2 input.
class DemographicContext {
  final int? ageYears;
  final SexGender? sexGender;

  const DemographicContext({this.ageYears, this.sexGender});

  Map<String, dynamic> toJson() => {
        'age_years': ageYears,
        'sex_gender': sexGender?.wireValue,
      };

  factory DemographicContext.fromJson(Map<String, dynamic> json) {
    final raw = json['sex_gender'] as String?;
    return DemographicContext(
      ageYears: (json['age_years'] as num?)?.toInt(),
      sexGender: raw == null
          ? null
          : SexGender.values.firstWhere(
              (v) => v.wireValue == raw,
              orElse: () => SexGender.unknown,
            ),
    );
  }
}

/// How the user is using the app (Stage 1.8). Context only — never
/// diagnostic evidence and never an input to the Layer 1 classifier.
enum MonitoringProfileType {
  diagnosed,
  monitoring,
  research,
}

extension MonitoringProfileTypeX on MonitoringProfileType {
  String get label {
    switch (this) {
      case MonitoringProfileType.diagnosed:
        return "Diagnosed with Parkinson's disease";
      case MonitoringProfileType.monitoring:
        return 'Monitoring possible movement changes';
      case MonitoringProfileType.research:
        return 'Research / healthy volunteer';
    }
  }
}

enum ReportedSymptom {
  tremor,
  stiffnessRigidity,
  slowness,
  balanceWalking,
  other,
}

extension ReportedSymptomX on ReportedSymptom {
  String get label {
    switch (this) {
      case ReportedSymptom.tremor:
        return 'Tremor';
      case ReportedSymptom.stiffnessRigidity:
        return 'Stiffness / rigidity';
      case ReportedSymptom.slowness:
        return 'Slowness';
      case ReportedSymptom.balanceWalking:
        return 'Balance / walking difficulty';
      case ReportedSymptom.other:
        return 'Other';
    }
  }
}

enum AffectedSide {
  left,
  right,
  both,
  unsure,
}

/// Optional diagnosed-pathway context (Stage 1.8). Everything nullable:
/// the core typing workflow never requires disclosure.
class ParkinsonContext {
  final int? diagnosisYear;
  final Set<ReportedSymptom> mainReportedSymptoms;
  final AffectedSide? moreAffectedSide;

  const ParkinsonContext({
    this.diagnosisYear,
    this.mainReportedSymptoms = const {},
    this.moreAffectedSide,
  });

  Map<String, dynamic> toJson() => {
        'diagnosis_year': diagnosisYear,
        'main_reported_symptoms':
            mainReportedSymptoms.map((s) => s.name).toList(),
        'more_affected_side': moreAffectedSide?.name,
      };
}

/// Medication context for diagnosed users (Stage 1.9).
/// Stored alongside the day's session for visualization context only.
/// Never a core ML input; never used to claim medication effect.
enum MedicationState {
  on,
  off,
  notSure,
  notApplicable,
}

/// Brief self-reported check-in (Stage 1.9).
///
/// A SEPARATE contextual time series. Deliberately has no feature-vector
/// conversion: symptom ratings, medication state, and free-text notes are
/// never fed into Layer 1 or Layer 2. Never converted into a clinical
/// score (no UPDRS/MDS-UPDRS language anywhere).
class SymptomCheckIn {
  final DateTime date;
  final int tremor;
  final int stiffness;
  final int slowness;
  final int balanceWalking;
  final int fatigue;
  final int sleepQuality;
  final String? note;
  final MedicationState? medicationState;
  final double? hoursSinceMedication;

  const SymptomCheckIn({
    required this.date,
    required this.tremor,
    required this.stiffness,
    required this.slowness,
    required this.balanceWalking,
    required this.fatigue,
    required this.sleepQuality,
    this.note,
    this.medicationState,
    this.hoursSinceMedication,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'tremor': tremor,
        'stiffness': stiffness,
        'slowness': slowness,
        'balance_walking': balanceWalking,
        'fatigue': fatigue,
        'sleep_quality': sleepQuality,
        'note': note,
        'medication_state': medicationState?.name,
        'hours_since_medication': hoursSinceMedication,
      };

  factory SymptomCheckIn.fromJson(Map<String, dynamic> json) {
    int v(String key) => (json[key] as num).toInt().clamp(0, 10);
    return SymptomCheckIn(
      date: DateTime.parse(json['date'] as String),
      tremor: v('tremor'),
      stiffness: v('stiffness'),
      slowness: v('slowness'),
      balanceWalking: v('balance_walking'),
      fatigue: v('fatigue'),
      sleepQuality: v('sleep_quality'),
      note: json['note'] as String?,
      medicationState: json['medication_state'] == null
          ? null
          : MedicationState.values.byName(json['medication_state'] as String),
      hoursSinceMedication:
          (json['hours_since_medication'] as num?)?.toDouble(),
    );
  }
}
