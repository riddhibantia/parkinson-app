import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';

/// Firebase REST layer for desktop (Stage 1.1 fallback).
///
/// Pre-Build Checklist 5a verdict on this Windows machine: the FlutterFire
/// C++ SDK signs in with an opaque `unknown-error`, while the plain REST
/// chain (sign-up → sign-in → Firestore write → read, under the deployed
/// owner-only rules) passes end to end. So on desktop the app talks to
/// Firebase over HTTPS directly; the plugin path stays for mobile.
/// No Firebase.initializeApp needed for anything in this file.
class FirebaseRestService {
  static const _prefsPrefix = 'firebase_rest_v1';

  final String apiKey;
  final String projectId;
  final http.Client _client;

  String? _uid;
  String? _idToken;
  String? _refreshToken;
  DateTime? _expiry;

  final _authState = StreamController<String?>.broadcast();

  FirebaseRestService({
    required this.apiKey,
    required this.projectId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory FirebaseRestService.fromOptions({http.Client? client}) {
    final web = DefaultFirebaseOptions.web;
    return FirebaseRestService(
      apiKey: web.apiKey,
      projectId: web.projectId,
      client: client,
    );
  }

  Stream<String?> get authStateChanges => _authState.stream;
  String? get uid => _uid;

  Uri _identity(String method) => Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:$method'
    '?key=$apiKey',
  );

  Future<void> signUp(String email, String password) async {
    final res = await _postJson(_identity('signUp'), {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }).timeout(const Duration(seconds: 15));
    _applyTokenResponse(_decode(res));
  }

  Future<void> signIn(String email, String password) async {
    final res = await _postJson(_identity('signInWithPassword'), {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }).timeout(const Duration(seconds: 15));
    _applyTokenResponse(_decode(res));
  }

  Future<void> sendPasswordReset(String email) async {
    final res = await _postJson(_identity('sendOobCode'), {
      'email': email,
      'requestType': 'PASSWORD_RESET',
    }).timeout(const Duration(seconds: 15));
    _decode(res); // throws FirebaseRestException on error
  }

  Future<void> signOut() async {
    _uid = null;
    _idToken = null;
    _refreshToken = null;
    _expiry = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['uid', 'refreshToken']) {
      await prefs.remove('$_prefsPrefix.$k');
    }
    _authState.add(null);
  }

  /// Restore a previous session (called once at startup). Best-effort:
  /// offline or expired-without-network simply yields signed-out.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('$_prefsPrefix.uid');
      final refresh = prefs.getString('$_prefsPrefix.refreshToken');
      if (uid == null || refresh == null) return;
      _uid = uid;
      _refreshToken = refresh;
      await _refreshIdToken();
      _authState.add(_uid);
    } catch (_) {
      _uid = null;
    }
  }

  Future<void> _refreshIdToken() async {
    final res = await _client
        .post(
          Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'grant_type': 'refresh_token',
            'refresh_token': _refreshToken,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw FirebaseRestException('token-refresh', res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    _idToken = body['id_token'] as String;
    _refreshToken = body['refresh_token'] as String;
    _expiry = DateTime.now().add(
      Duration(seconds: int.parse(body['expires_in'] as String)),
    );
    await _persist();
  }

  Future<String> _freshIdToken() async {
    if (_idToken == null || _refreshToken == null) {
      throw FirebaseRestException('not-signed-in', 'No local session');
    }
    if (_expiry == null ||
        DateTime.now().isAfter(_expiry!.subtract(const Duration(minutes: 1)))) {
      await _refreshIdToken();
    }
    return _idToken!;
  }

  void _applyTokenResponse(Map<String, dynamic> body) {
    _uid = body['localId'] as String;
    _idToken = body['idToken'] as String;
    _refreshToken = body['refreshToken'] as String;
    _expiry = DateTime.now().add(
      Duration(seconds: int.parse(body['expiresIn'] as String)),
    );
    unawaited(_persist());
    _authState.add(_uid);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_uid != null) {
      await prefs.setString('$_prefsPrefix.uid', _uid!);
    }
    if (_refreshToken != null) {
      await prefs.setString('$_prefsPrefix.refreshToken', _refreshToken!);
    }
  }

  Future<http.Response> _postJson(Uri url, Map<String, dynamic> body) {
    return _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      throw FirebaseRestException(
        error?['message'] as String? ?? 'unknown',
        res.body,
      );
    }
    return body;
  }

  // ---------- Firestore ----------

  String get _fsBase =>
      'https://firestore.googleapis.com/v1/projects/$projectId'
      '/databases/(default)/documents';

  Future<Map<String, String>> _authHeaders() async {
    final token = await _freshIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Create-or-replace a document (PATCH upsert). Path segments relative
  /// to the database documents root, e.g. ['users', uid, 'sessions', id].
  Future<void> setDocument(List<String> path, Map<String, dynamic> json) async {
    final docPath = path.join('/');
    final uri = Uri.parse('$_fsBase/$docPath');
    Map<String, String> headers;
    try {
      headers = await _authHeaders();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[FIREBASE DIAG] setDocument pre-auth failed: projectId=$projectId path=$docPath hasToken=${_idToken != null} uid=$_uid error=$e',
        );
      }
      rethrow;
    }
    if (kDebugMode) {
      final hasToken = headers['Authorization'] != null;
      debugPrint(
        '[FIREBASE DIAG] firestore-write: projectId=$projectId path=$docPath hasToken=$hasToken uid=$_uid tokenExists=${_idToken != null}',
      );
    }
    final res = await _client
        .patch(
          uri,
          headers: headers,
          body: jsonEncode({'fields': _encodeMap(json)}),
        )
        .timeout(const Duration(seconds: 15));
    if (kDebugMode) {
      debugPrint(
        '[FIREBASE DIAG] response: status=${res.statusCode} body=${res.body.length > 500 ? res.body.substring(0, 500) : res.body}',
      );
    }
    if (res.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[FIREBASE DIAG] firestore-write FAILED: projectId=$projectId path=$docPath uid=$_uid status=${res.statusCode}',
        );
      }
      throw FirebaseRestException(
        'firestore-write: ${res.statusCode}',
        res.body,
      );
    }
  }

  /// Get one document; returns null when missing.
  Future<Map<String, dynamic>?> getDocument(List<String> path) async {
    final res = await _client
        .get(
          Uri.parse('$_fsBase/${path.join('/')}'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw FirebaseRestException(
        'firestore-read: ${res.statusCode}',
        res.body,
      );
    }
    return _decodeDocument(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// List a collection's documents, newest first by `timestamp`.
  Future<List<Map<String, dynamic>>> listCollection(
    List<String> collectionPath, {
    int pageSize = 50,
  }) async {
    final res = await _client
        .get(
          Uri.parse(
            '$_fsBase/${collectionPath.join('/')}'
            '?orderBy=timestamp%20desc&pageSize=$pageSize',
          ),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw FirebaseRestException(
        'firestore-list: ${res.statusCode}',
        res.body,
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List?) ?? [];
    return [for (final d in docs) _decodeDocument(d as Map<String, dynamic>)];
  }

  // ---------- Firestore value codec ----------

  Map<String, dynamic> _encodeMap(Map<String, dynamic> map) => {
    for (final e in map.entries) e.key: _encodeValue(e.value),
  };

  Map<String, dynamic> _encodeValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Timestamp) {
      return {'timestampValue': value.toDate().toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': [for (final v in value) _encodeValue(v)],
        },
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeMap(value)},
      };
    }
    if (value is Map) {
      return {
        'mapValue': {'fields': _encodeMap(Map<String, dynamic>.from(value))},
      };
    }
    throw ArgumentError('Unencodable Firestore value: ${value.runtimeType}');
  }

  Map<String, dynamic> _decodeDocument(Map<String, dynamic> doc) {
    final name = doc['name'] as String;
    final fields = (doc['fields'] as Map?) ?? {};
    return {
      ..._decodeMap(Map<String, dynamic>.from(fields)),
      '_docId': name.split('/').last,
    };
  }

  Map<String, dynamic> _decodeMap(Map<String, dynamic> fields) => {
    for (final e in fields.entries) e.key: _decodeValue(e.value),
  };

  Object? _decodeValue(Object? wire) {
    final map = Map<String, dynamic>.from(wire as Map);
    if (map.containsKey('nullValue')) return null;
    if (map.containsKey('booleanValue')) return map['booleanValue'] as bool;
    if (map.containsKey('integerValue')) {
      return int.parse(map['integerValue'] as String);
    }
    if (map.containsKey('doubleValue')) {
      return (map['doubleValue'] as num).toDouble();
    }
    if (map.containsKey('stringValue')) return map['stringValue'] as String;
    if (map.containsKey('timestampValue')) {
      return DateTime.parse(map['timestampValue'] as String);
    }
    if (map.containsKey('arrayValue')) {
      final values = ((map['arrayValue'] as Map)['values'] as List?) ?? [];
      return [for (final v in values) _decodeValue(v)];
    }
    if (map.containsKey('mapValue')) {
      final fields = ((map['mapValue'] as Map)['fields'] as Map?) ?? {};
      return _decodeMap(Map<String, dynamic>.from(fields));
    }
    if (map.containsKey('referenceValue')) return map['referenceValue'];
    if (map.containsKey('geoPointValue')) return map['geoPointValue'];
    throw ArgumentError('Undecodable Firestore value: $map');
  }
}

class FirebaseRestException implements Exception {
  final String code;
  final String details;
  FirebaseRestException(this.code, this.details);

  @override
  String toString() => 'FirebaseRestException($code)';
}
