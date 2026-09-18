import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/typing_session.dart';

/// Offline buffer for unsynced typing sessions (Stage 2.5).
/// Sessions persist here when offline or when Firebase is not yet
/// configured, and are pushed by [SessionRepository.syncPending] once a
/// signed-in backend is reachable. Text content is never part of the
/// payload — only timing events.
class LocalStorageService {
  static const _pendingKey = 'pending_sessions_v1';

  Future<List<TypingSession>> loadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => TypingSession.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addPending(TypingSession session) async {
    final current = await loadPending();
    current.add(session);
    await _writeAll(current);
  }

  Future<void> removePending(List<String> sessionIds) async {
    final current = await loadPending();
    current.removeWhere((s) => sessionIds.contains(s.sessionId));
    await _writeAll(current);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<void> _writeAll(List<TypingSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }
}
