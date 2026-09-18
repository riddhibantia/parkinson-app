import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinson_app/data/models/keystroke_event.dart';
import 'package:parkinson_app/data/models/typing_session.dart';
import 'package:parkinson_app/data/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

TypingSession _session(String id, {String phase = 'screening'}) {
  return TypingSession(
    sessionId: id,
    userId: 'u1',
    startTime: DateTime(2026, 9, 17, 10, 0, 0),
    endTime: DateTime(2026, 9, 17, 10, 1, 0),
    mode: 'structured',
    sessionPhase: phase,
    events: const [
      KeystrokeEvent(
        pressTimestamp: 1000,
        releaseTimestamp: 110000,
        hand: 'left',
        row: 1,
        keyType: KeyType.character,
      ),
    ],
    totalKeystrokes: 1,
    deviceId: 'laptop-keyboard',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TypingSession toJson/fromJson round-trip', () {
    final restored =
        TypingSession.fromJson(_session('s1').toJson());
    expect(restored.sessionId, 's1');
    expect(restored.events.single.hand, 'left');
    expect(restored.isFamiliarization, isFalse);
    expect(
      _session('p1', phase: 'familiarization').isFamiliarization,
      isTrue,
    );
  });

  test('saveSession buffers locally when backend not ready', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SessionRepository(); // no Firebase handles
    expect(repo.backendReady, isFalse);

    await repo.saveSession(_session('s1'));
    await repo.saveSession(_session('s2'));
    final pending = await repo.loadLocalSessions();
    expect(pending.map((s) => s.sessionId), ['s1', 's2']);
  });

  test('syncPending is a no-op offline and keeps the buffer', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SessionRepository();
    await repo.saveSession(_session('s1'));
    expect(await repo.syncPending(), 0);
    expect((await repo.loadLocalSessions()).length, 1);
  });

  test('clearLocalData empties the buffer', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SessionRepository();
    await repo.saveSession(_session('s1'));
    await repo.clearLocalData();
    expect(await repo.loadLocalSessions(), isEmpty);
  });

  test('firestore.rules enforces owner-only access', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains('/users/{userId}'));
    expect(rules, contains('/sessions/{sessionId}'));
    expect(rules, contains('/baselines/{baselineId}'));
    expect(rules, contains('/results/{resultId}'));
    // Reference data readable when signed in, never client-writable.
    expect(rules, contains('allow write: if false'));
  });
}
