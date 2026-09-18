import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_rest_service.dart';

/// Auth contract (Stage 1.5). The Firebase implementation is used once
/// `flutterfire configure` has generated firebase_options.dart for the
/// fresh project. Until then the app runs against [LocalAuthRepository]
/// so UI work is not blocked on console setup.
abstract class AuthRepository {
  Stream<String?> authStateChanges();
  String? get currentUserId;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signInWithGoogle();
  Future<void> signOut({Future<void> Function()? flushBeforeSignOut});
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  FirebaseAuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signInWithGoogle() {
    // Google provider wiring lands with firebase_options + platform
    // client IDs. Kept explicit so it is not silently half-working.
    throw UnimplementedError(
      'Google sign-in is wired after flutterfire configure.',
    );
  }

  @override
  Future<void> signOut({Future<void> Function()? flushBeforeSignOut}) async {
    // Flush locally-buffered unsynced sessions first (Stage 2.4),
    // or warn if still pending — never drop silently.
    if (flushBeforeSignOut != null) await flushBeforeSignOut();
    await _auth.signOut();
  }
}

/// Temporary local stand-in until Firebase is configured.
/// Not a second auth system — removed once firebase_options.dart exists.
class LocalAuthRepository implements AuthRepository {
  String? _uid;
  final _controller = Stream<String?>.empty();

  @override
  Stream<String?> authStateChanges() => _controller;

  @override
  String? get currentUserId => _uid;

  @override
  Future<void> signIn(String email, String password) async {
    _uid = 'local-${email.hashCode}';
  }

  @override
  Future<void> signUp(String email, String password) async {
    _uid = 'local-${email.hashCode}';
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google sign-in needs Firebase configuration.');
  }

  @override
  Future<void> signOut({Future<void> Function()? flushBeforeSignOut}) async {
    if (flushBeforeSignOut != null) await flushBeforeSignOut();
    _uid = null;
  }
}

/// REST auth for desktop (Stage 1.1 fallback path, 5a-verified).
/// Same contract as [FirebaseAuthRepository]; Google sign-in stays
/// unimplemented on desktop until OAuth client IDs are wired.
class RestAuthRepository implements AuthRepository {
  final FirebaseRestService _rest;
  RestAuthRepository({required FirebaseRestService rest}) : _rest = rest;

  @override
  Stream<String?> authStateChanges() => _rest.authStateChanges;

  @override
  String? get currentUserId => _rest.uid;

  @override
  Future<void> signIn(String email, String password) =>
      _rest.signIn(email, password);

  @override
  Future<void> signUp(String email, String password) =>
      _rest.signUp(email, password);

  @override
  Future<void> sendPasswordReset(String email) =>
      _rest.sendPasswordReset(email);

  @override
  Future<void> signInWithGoogle() async {
    throw UnimplementedError(
      'Google sign-in on desktop needs OAuth client wiring (Stage 6).',
    );
  }

  @override
  Future<void> signOut({Future<void> Function()? flushBeforeSignOut}) async {
    if (flushBeforeSignOut != null) await flushBeforeSignOut();
    await _rest.signOut();
  }
}
