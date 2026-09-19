import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/data/services/motor_task_service.dart';

void main() {
  test('MotorTap payload matches Python extractor input keys', () {
    const tap = MotorTap(timestampMs: 1700000000000, key: 'F');
    expect(tap.toJson(), {'timestamp_ms': 1700000000000, 'key': 'F'});
  });

  test('recorder accepts only the two task keys', () {
    expect(MotorTaskRecorder.taskKeys, {'F', 'J'});
  });
}
