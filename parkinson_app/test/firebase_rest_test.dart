import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinson_app/data/models/typing_session.dart';
import 'package:parkinson_app/data/repositories/session_repository.dart';
import 'package:parkinson_app/data/services/firebase_rest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apiKey = 'test-key';
const _project = 'parkinson-app-rbt';

Map<String, dynamic> _tokenBody() => {
      'localId': 'uid-1',
      'idToken': 'id-token',
      'refreshToken': 'refresh-token',
      'expiresIn': '3600',
    };

FirebaseRestService _service(MockClient client) =>
    FirebaseRestService(apiKey: _apiKey, projectId: _project, client: client);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signIn stores uid and emits auth state', () async {
    final service = _service(MockClient((req) async {
      return http.Response(jsonEncode(_tokenBody()), 200);
    }));
    final seen = <String?>[];
    final sub = service.authStateChanges.listen(seen.add);
    await service.signIn('a@b.c', 'secret12').timeout(
      const Duration(seconds: 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(service.uid, 'uid-1');
    expect(seen, ['uid-1']);
  });

  test('signIn error surfaces FirebaseRestException', () async {
    final service = _service(MockClient((req) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'INVALID_LOGIN_CREDENTIALS'}
        }),
        400,
      );
    }));
    expect(
      () => service.signIn('a@b.c', 'wrong'),
      throwsA(isA<FirebaseRestException>()),
    );
  });

  test('setDocument PATCHes the owner-scoped path with encoded fields',
      () async {
    String? method;
    String? url;
    Map<String, dynamic>? fields;
    final service = _service(MockClient((req) async {
      if (req.url.host.contains('identitytoolkit')) {
        return http.Response(jsonEncode(_tokenBody()), 200);
      }
      method = req.method;
      url = req.url.toString();
      fields =
          (jsonDecode(req.body) as Map<String, dynamic>)['fields']
              as Map<String, dynamic>;
      return http.Response(jsonEncode({'name': 'd'}), 200);
    }));
    await service.signIn('a@b.c', 'secret12');
    await service.setDocument(
      ['users', 'uid-1', 'sessions', 's1'],
      {
        'mode': 'structured',
        'keystroke_count': 7,
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 9, 17)),
        'metadata': {'a': 1},
      },
    );
    expect(method, 'PATCH');
    expect(
      url,
      contains('projects/$_project/databases/(default)/documents'
          '/users/uid-1/sessions/s1'),
    );
    expect(fields!['mode'], {'stringValue': 'structured'});
    expect(fields!['keystroke_count'], {'integerValue': '7'});
    expect(fields!['timestamp']['timestampValue'],
        contains('2026-09-17'));
    expect(fields!['metadata']['mapValue']['fields']['a'],
        {'integerValue': '1'});
  });

  test('getDocument returns null on 404', () async {
    final service = _service(MockClient((req) async {
      if (req.url.host.contains('identitytoolkit')) {
        return http.Response(jsonEncode(_tokenBody()), 200);
      }
      return http.Response('{}', 404);
    }));
    await service.signIn('a@b.c', 'secret12');
    expect(
      await service.getDocument(['users', 'uid-1', 'sessions', 'missing']),
      isNull,
    );
  });

  test('listCollection decodes documents with doc ids', () async {
    final service = _service(MockClient((req) async {
      if (req.url.host.contains('identitytoolkit')) {
        return http.Response(jsonEncode(_tokenBody()), 200);
      }
      return http.Response(
        jsonEncode({
          'documents': [
            {
              'name': 'projects/p/databases/(default)/documents'
                  '/users/uid-1/sessions/s9',
              'fields': {
                'mode': {'stringValue': 'free'},
                'keystroke_count': {'integerValue': '3'},
              },
            },
          ],
        }),
        200,
      );
    }));
    await service.signIn('a@b.c', 'secret12');
    final docs = await service.listCollection(['users', 'uid-1', 'sessions']);
    expect(docs.single['_docId'], 's9');
    expect(docs.single['mode'], 'free');
    expect(docs.single['keystroke_count'], 3);
  });

  test('SessionRepository saves via REST when signed in', () async {
    var patched = 0;
    final client = MockClient((req) async {
      if (req.url.host.contains('identitytoolkit')) {
        return http.Response(jsonEncode(_tokenBody()), 200);
      }
      if (req.method == 'PATCH') patched++;
      return http.Response(jsonEncode({'name': 'd'}), 200);
    });
    final rest = _service(client);
    await rest.signIn('a@b.c', 'secret12');
    final repo = SessionRepository(restService: rest);
    expect(repo.backendReady, isFalse);
    expect(repo.restReady, isTrue);

    await repo.saveSession(TypingSession(
      sessionId: 's1',
      userId: 'uid-1',
      startTime: DateTime(2026, 9, 17, 10),
      endTime: DateTime(2026, 9, 17, 10, 1),
      mode: 'structured',
      sessionPhase: 'screening',
      events: const [],
      totalKeystrokes: 0,
      deviceId: 'kbd',
    ));
    expect(patched, 1);
    expect(await repo.loadLocalSessions(), isEmpty);
  });

  test('saved documents carry the backend dispatch contract', () async {
    Map<String, dynamic>? sentFields;
    final client = MockClient((req) async {
      if (req.url.host.contains('identitytoolkit')) {
        return http.Response(jsonEncode(_tokenBody()), 200);
      }
      sentFields = (jsonDecode(req.body)
              as Map<String, dynamic>)['fields']
          as Map<String, dynamic>;
      return http.Response(jsonEncode({'name': 'd'}), 200);
    });
    final rest = _service(client);
    await rest.signIn('a@b.c', 'secret12');
    final repo = SessionRepository(restService: rest);

    await repo.saveSession(TypingSession(
      sessionId: 's9',
      userId: 'uid-1',
      startTime: DateTime(2026, 9, 17, 10),
      endTime: DateTime(2026, 9, 17, 10, 0, 20),
      mode: 'structured',
      sessionPhase: 'screening',
      events: const [],
      totalKeystrokes: 0,
      deviceId: 'kbd',
    ));

    final fields = sentFields!;
    expect(fields['duration_sec']['doubleValue'], 20.0);
    expect(fields['keystroke_count']['integerValue'], '0');
    final flags = (fields['quality_flags']['arrayValue']['values'] as List)
        .map((v) => (v as Map)['stringValue'])
        .toList();
    expect(flags, containsAll(['too_short', 'too_few_keystrokes']));
  });
}
