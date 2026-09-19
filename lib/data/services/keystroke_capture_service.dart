import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/models/keystroke_event.dart';

/// Left/right hand zones by physical key position (QWERTY).
/// Raw key identity is consumed here and never leaves this function.
String _handFor(LogicalKeyboardKey key) {
  final id = key.keyId;
  // Left-hand block: Q W E R T A S D F G Z X C V B (+ Tab, Caps, Shift-left)
  const leftKeys = {
    0x00000071, // q
    0x00000077, // w
    0x00000065, // e
    0x00000072, // r
    0x00000074, // t
    0x00000061, // a
    0x00000073, // s
    0x00000064, // d
    0x00000066, // f
    0x00000067, // g
    0x0000007a, // z
    0x00000078, // x
    0x00000063, // c
    0x00000076, // v
    0x00000062, // b
  };
  if (leftKeys.contains(id)) return 'left';
  return 'right';
}

int _rowFor(LogicalKeyboardKey key) {
  final label = key.keyLabel.toLowerCase();
  if ('qwertyuiop'.contains(label) && label.length == 1) return 0;
  if ('asdfghjkl'.contains(label) && label.length == 1) return 1;
  if ('zxcvbnm'.contains(label) && label.length == 1) return 2;
  return 1;
}

/// Session-scoped physical key-event listener (Stage 2.1).
///
/// Attach to one focused typing field for the duration of an active
/// session only. NOT a system-wide hook: losing focus or closing the
/// typing screen stops capture. Uses raw OS-level event timestamps.
class KeystrokeCaptureService extends ChangeNotifier {
  final List<KeystrokeEvent> _events = [];
  final Map<int, int> _pressTimes = {};
  bool _active = false;
  final void Function()? onEvent;

  KeystrokeCaptureService({this.onEvent});

  List<KeystrokeEvent> get events => List.unmodifiable(_events);
  bool get isActive => _active;

  void startSession() {
    _events.clear();
    _pressTimes.clear();
    _active = true;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  void stopSession() {
    _active = false;
    HardwareKeyboard.instance.removeHandler(_handleKey);
  }

  /// Categorize at capture time (Stage 2.1a).
  KeyType? categorize(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.backspace) return KeyType.backspace;
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.escape ||
        key.keyLabel.isEmpty) {
      return KeyType.control;
    }
    return KeyType.character;
  }

  bool _handleKey(KeyEvent event) {
    if (!_active) return false;
    final type = categorize(event.logicalKey);
    if (type == null || type == KeyType.control) return false;

    final nowUs = DateTime.now().microsecondsSinceEpoch;
    final id = event.logicalKey.keyId;

    if (event is KeyDownEvent) {
      _pressTimes[id] = nowUs;
    } else if (event is KeyUpEvent) {
      final press = _pressTimes.remove(id);
      if (press == null) return false;
      // Derive hand/row now; raw key identity never stored.
      _events.add(KeystrokeEvent(
        pressTimestamp: press,
        releaseTimestamp: nowUs,
        hand: _handFor(event.logicalKey),
        row: _rowFor(event.logicalKey),
        keyType: type,
      ));
      onEvent?.call();
      notifyListeners();
    }
    return false; // never consume — typing must behave normally
  }

  /// Backspace corrections per minute — kept separate so correction
  /// bursts never distort FT/IKL rhythm features (Stage 2.1a/3.2).
  double backspaceRatePerMinute(Duration sessionDuration) {
    if (sessionDuration.inSeconds == 0) return 0;
    final n =
        _events.where((e) => e.keyType == KeyType.backspace).length;
    return n / (sessionDuration.inSeconds / 60.0);
  }

  @override
  void dispose() {
    if (_active) stopSession();
    super.dispose();
  }
}
