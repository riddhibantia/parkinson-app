import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/session_utils.dart';
import '../models/typing_session.dart';
import '../services/firebase_rest_service.dart';
import '../services/local_storage_service.dart';

/// Session persistence (Stage 2.5 / 6.4).
///
/// Provisional path: writes accepted sessions straight to
/// `users/{uid}/sessions` (plan schema). In Stage 6 the `submit_session`
/// callable takes over validation + persistence and this repository calls
/// it instead — the document shape stays identical, so no migration.
///
/// Offline or pre-configuration: sessions buffer in [LocalStorageService]
/// and [syncPending] pushes them once a signed-in backend is reachable.
/// Sign-out must call [syncPending] first (flush hook, Stage 1.5).
class SessionRepository {
  final LocalStorageService _local;
  final FirebaseFirestore? _db;
  final FirebaseAuth? _auth;
  final FirebaseRestService? _restService;

  SessionRepository({
    LocalStorageService? local,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseRestService? restService,
  })  : _local = local ?? LocalStorageService(),
        _db = db,
        _auth = auth,
        _restService = restService;

  bool get backendReady {
    if (_db == null) return false;
    if (Firebase.apps.isEmpty) return false;
    return _auth?.currentUser != null;
  }

  /// REST backend (desktop fallback): ready when signed in via REST.
  bool get restReady => _restService?.uid != null;
  String? get _restUid => _restService?.uid;

  String? get _uid => _auth?.currentUser?.uid;

  Future<List<TypingSession>> loadLocalSessions() => _local.loadPending();

  /// Delete all on-device buffered sessions (Settings, Stage 9.3).
  Future<void> clearLocalData() => _local.clearAll();

  /// Persist one finished session: plugin backend when reachable, else
  /// REST backend when signed in, else the on-device buffer.
  Future<void> saveSession(TypingSession session) async {
    if (backendReady) {
      await _db!
          .collection('users')
          .doc(_uid)
          .collection('sessions')
          .doc(session.sessionId)
          .set(_documentOf(session));
    } else if (restReady) {
      await _restService!.setDocument(
        ['users', _restUid!, 'sessions', session.sessionId],
        _documentOf(session),
      );
    } else {
      await _local.addPending(session);
    }
  }

  /// Push buffered sessions, then drop the ones the backend accepted.
  Future<int> syncPending() async {
    if (!backendReady && !restReady) return 0;
    final pending = await _local.loadPending();
    var synced = 0;
    final accepted = <String>[];
    for (final session in pending) {
      if (backendReady) {
        await _db!
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(session.sessionId)
            .set(_documentOf(session));
      } else {
        await _restService!.setDocument(
          ['users', _restUid!, 'sessions', session.sessionId],
          _documentOf(session),
        );
      }
      accepted.add(session.sessionId);
      synced++;
    }
    await _local.removePending(accepted);
    return synced;
  }

  /// Live session list when a backend is ready, else the local buffer.
  Stream<List<TypingSession>> watchSessions() {
    if (backendReady) {
      return _db!
          .collection('users')
          .doc(_uid)
          .collection('sessions')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => TypingSession.fromJson({
                    ...d.data(),
                    'sessionId': d.id,
                  }))
              .toList());
    }
    if (restReady) {
      return Stream.fromFuture(_listViaRest());
    }
    return Stream.fromFuture(_local.loadPending());
  }

  Future<List<TypingSession>> _listViaRest() async {
    final docs = await _restService!
        .listCollection(['users', _restUid!, 'sessions']);
    return [
      for (final d in docs)
        TypingSession.fromJson({
          ...d..remove('_docId'),
          'sessionId': d['_docId'],
        }),
    ];
  }

  /// Latest stored analysis result (dual Layer 1/Layer 2 shape once
  /// monitoring is active). Null when signed out or when no result
  /// exists yet — callers show readiness shells instead.
  Future<Map<String, dynamic>?> watchLatestResult() async {
    if (backendReady) {
      final snap = await _db!
          .collection('users')
          .doc(_uid)
          .collection('results')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    }
    if (restReady) {
      final docs = await _restService!.listCollection(
        ['users', _restUid!, 'results'],
        pageSize: 1,
      );
      if (docs.isEmpty) return null;
      return docs.first..remove('_docId');
    }
    return null;
  }

  /// Frozen personal baseline document, if one has been built.
  /// Shape: {features: {name: {median, mad, mean, std, ...}}, ...}.
  Future<Map<String, dynamic>?> fetchBaseline() async {
    if (backendReady) {
      final doc = await _db!
          .collection('users')
          .doc(_uid)
          .collection('baselines')
          .doc('current')
          .get();
      if (!doc.exists) return null;
      return doc.data();
    }
    if (restReady) {
      final doc = await _restService!.getDocument(
        ['users', _restUid!, 'baselines', 'current'],
      );
      doc?.remove('_docId');
      return doc;
    }
    return null;
  }

  /// Backend dispatch contract (Stage 6.3): the analysis trigger reads
  /// duration_sec, keystroke_count, and quality_flags straight off the
  /// document, so every write path stamps them here — never assumed.
  Map<String, dynamic> _documentOf(TypingSession session) {
    final json = session.toJson()..remove('sessionId');
    json['timestamp'] = Timestamp.fromDate(session.startTime);
    final duration = session.endTime.difference(session.startTime);
    json['duration_sec'] = duration.inMilliseconds / 1000.0;
    json['keystroke_count'] = session.totalKeystrokes;
    json['quality_flags'] =
        SessionQuality.check(events: session.events, activeDuration: duration);
    return json;
  }
}

final firebaseRestProvider = Provider<FirebaseRestService>((ref) {
  // Web options double as the desktop REST config (5a-verified pattern).
  return FirebaseRestService.fromOptions();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final rest = ref.watch(firebaseRestProvider);
  if (Firebase.apps.isEmpty) return SessionRepository(restService: rest);
  return SessionRepository(
    db: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    restService: rest,
  );
});

final localSessionsProvider =
    FutureProvider<List<TypingSession>>((ref) async {
  return ref.watch(sessionRepositoryProvider).loadLocalSessions();
});
