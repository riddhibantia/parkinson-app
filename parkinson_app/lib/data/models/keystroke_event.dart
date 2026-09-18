/// Single key press/release event (Stage 2.1).
///
/// Privacy: the raw physical key code is used only transiently at capture
/// time to derive [hand]/[row]/[keyType], then discarded. It is never a
/// field here, never buffered, never sent.
enum KeyType { character, backspace, control }

class KeystrokeEvent {
  /// Microseconds since epoch from the OS event timestamp.
  final int pressTimestamp;

  /// Microseconds since epoch from the OS event timestamp.
  final int releaseTimestamp;

  /// Derived from key position, then raw key identity is discarded.
  final String hand; // "left" | "right"

  /// Keyboard row (0=top, 1=middle, 2=bottom) — derived, keyId discarded.
  final int row;

  final KeyType keyType;

  const KeystrokeEvent({
    required this.pressTimestamp,
    required this.releaseTimestamp,
    required this.hand,
    required this.row,
    required this.keyType,
  });

  int get holdTimeUs => releaseTimestamp - pressTimestamp;

  Map<String, dynamic> toJson() => {
        'pressTimestamp': pressTimestamp,
        'releaseTimestamp': releaseTimestamp,
        'hand': hand,
        'row': row,
        'keyType': keyType.name,
      };

  factory KeystrokeEvent.fromJson(Map<String, dynamic> json) {
    return KeystrokeEvent(
      pressTimestamp: json['pressTimestamp'] as int,
      releaseTimestamp: json['releaseTimestamp'] as int,
      hand: json['hand'] as String,
      row: json['row'] as int,
      keyType: KeyType.values.byName(json['keyType'] as String),
    );
  }
}
