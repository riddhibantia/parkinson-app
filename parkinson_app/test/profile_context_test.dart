import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/data/models/user_profile.dart';

void main() {
  test('demographics round-trip; unknown values never block', () {
    const empty = DemographicContext();
    expect(empty.ageYears, isNull);
    expect(empty.sexGender, isNull);
    expect(
      DemographicContext.fromJson(empty.toJson()).toJson(),
      empty.toJson(),
    );

    const full = DemographicContext(
      ageYears: 68,
      sexGender: SexGender.preferNotToSay,
    );
    final restored = DemographicContext.fromJson(full.toJson());
    expect(restored.ageYears, 68);
    expect(restored.sexGender, SexGender.preferNotToSay);
  });

  test('unrecognized sex/gender wire value falls back to unknown', () {
    final restored = DemographicContext.fromJson(
      {'age_years': null, 'sex_gender': 'X'},
    );
    expect(restored.sexGender, SexGender.unknown);
  });

  test('check-in ratings clamp to 0-10 and stay serializable', () {
    final checkIn = SymptomCheckIn.fromJson({
      'date': DateTime(2026, 9, 17).toIso8601String(),
      'tremor': 99,
      'stiffness': -3,
      'slowness': 5,
      'balance_walking': 4,
      'fatigue': 6,
      'sleep_quality': 7,
      'note': null,
      'medication_state': null,
      'hours_since_medication': null,
    });
    expect(checkIn.tremor, 10);
    expect(checkIn.stiffness, 0);
    expect(checkIn.medicationState, isNull);
  });

  test('check-in JSON shares no keys with ML typing features', () {
    const typingKeys = {
      'ht_mean', 'ht_std', 'ft_mean', 'ft_std', 'ikl_mean', 'ikl_std',
      'left_ht_mean', 'right_ht_mean', 'hand_asymmetry', 'pause_frequency',
      'typing_speed', 'session_consistency', 'backspace_rate',
    };
    final checkIn = SymptomCheckIn(
      date: DateTime(2026, 9, 17),
      tremor: 2,
      stiffness: 3,
      slowness: 1,
      balanceWalking: 0,
      fatigue: 4,
      sleepQuality: 8,
      medicationState: MedicationState.off,
      hoursSinceMedication: 5.5,
    );
    final keys = checkIn.toJson().keys.toSet();
    expect(keys.intersection(typingKeys), isEmpty);
  });

  test('parkinson context fully optional', () {
    const context = ParkinsonContext();
    expect(context.diagnosisYear, isNull);
    expect(context.mainReportedSymptoms, isEmpty);
    expect(context.moreAffectedSide, isNull);
    expect(context.toJson()['diagnosis_year'], isNull);
  });
}
