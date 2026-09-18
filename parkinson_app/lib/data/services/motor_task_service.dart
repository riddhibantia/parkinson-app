import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// One alternating-key tap: task mechanics only, no typed content.
class MotorTap {
  final int timestampMs;
  final String key; // "F" or "J"

  const MotorTap({required this.timestampMs, required this.key});

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestampMs,
        'key': key,
      };
}

/// Task-scoped alternating-key recorder (Stage 2.3).
///
/// Records ONLY the two task keys (F/J) with press timestamps while the
/// motor-task screen is active. Every other key is ignored, and nothing
/// resembling typed content is captured — this is deliberately separate
/// from [KeystrokeCaptureService], which discards key identity entirely.
class MotorTaskRecorder extends ChangeNotifier {
  static const taskKeys = {'F', 'J'};
  final List<MotorTap> _taps = [];
  bool _active = false;

  List<MotorTap> get taps => List.unmodifiable(_taps);
  bool get isActive => _active;

  void start() {
    _taps.clear();
    _active = true;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  void stop() {
    _active = false;
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    if (!_active || event is! KeyDownEvent) return false;
    final label = event.logicalKey.keyLabel.toUpperCase();
    if (!taskKeys.contains(label)) return false;
    _taps.add(MotorTap(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      key: label,
    ));
    notifyListeners();
    return false; // never consume — task must behave normally
  }

  List<Map<String, dynamic>> finishPayload() =>
      _taps.map((t) => t.toJson()).toList();

  @override
  void dispose() {
    if (_active) stop();
    super.dispose();
  }
}
