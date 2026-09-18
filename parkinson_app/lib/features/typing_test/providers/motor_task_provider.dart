import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/motor_task_service.dart';

/// Motor-task run state (Stage 2.3). One run records a single orientation
/// label so side-specific performance can be tracked later without
/// claiming a diagnosis. Full ITI statistics run server-side (Stage 3.2a).
class MotorTaskState {
  final bool running;
  final bool done;
  final String orientation;
  final int tapCount;
  final List<MotorTap> taps;

  const MotorTaskState({
    this.running = false,
    this.done = false,
    this.orientation = 'standard',
    this.tapCount = 0,
    this.taps = const [],
  });
}

class MotorTaskNotifier extends StateNotifier<MotorTaskState> {
  MotorTaskRecorder? _recorder;

  MotorTaskNotifier() : super(const MotorTaskState());

  void start({String orientation = 'standard'}) {
    _recorder?.dispose();
    final recorder = MotorTaskRecorder();
    recorder.addListener(() {
      state = MotorTaskState(
        running: true,
        orientation: state.orientation,
        tapCount: recorder.taps.length,
        taps: state.taps,
      );
    });
    _recorder = recorder;
    recorder.start();
    state = MotorTaskState(running: true, orientation: orientation);
  }

  MotorTaskState finish() {
    final recorder = _recorder;
    final taps = recorder == null ? const <MotorTap>[] : List<MotorTap>.of(recorder.taps);
    recorder?.stop();
    _recorder = null;
    state = MotorTaskState(
      done: true,
      orientation: state.orientation,
      tapCount: taps.length,
      taps: taps,
    );
    return state;
  }

  /// Payload keys match the Python extractor input exactly
  /// ({timestamp_ms, key}).
  List<Map<String, dynamic>> payload() =>
      state.taps.map((t) => t.toJson()).toList();
}

final motorTaskProvider =
    StateNotifierProvider<MotorTaskNotifier, MotorTaskState>(
  (ref) => MotorTaskNotifier(),
);
