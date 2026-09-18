import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/core/constants/app_constants.dart';
import 'package:parkinson_app/data/models/session_features.dart';

void main() {
  test('toJson/fromJson round-trip preserves all fields', () {
    const original = SessionFeatures(
      htMean: 100.0,
      htStd: 12.5,
      ftMean: 200.0,
      ftStd: 30.0,
      iklMean: 300.0,
      iklStd: 35.0,
      leftHtMean: 98.0,
      rightHtMean: 102.0,
      handAsymmetry: 0.04,
      pauseFrequency: 1.5,
      typingSpeed: 2.5,
      sessionConsistency: 0.12,
      backspaceRate: 3.0,
    );
    final restored = SessionFeatures.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(restored.validTaps, isNull); // typing session: no motor fields
  });

  test('valueOf covers every familiarization core feature', () {
    const features = SessionFeatures(
      htMean: 1,
      htStd: 2,
      ftMean: 3,
      ftStd: 4,
      iklMean: 5,
      iklStd: 6,
      typingSpeed: 7,
      pauseFrequency: 8,
      handAsymmetry: 9,
    );
    for (final name in AppConstants.familiarizationCoreFeatures) {
      expect(features.valueOf(name), isNotNull,
          reason: 'valueOf missing core feature: $name');
    }
    expect(features.valueOf('unknown_feature'), isNull);
  });
}
