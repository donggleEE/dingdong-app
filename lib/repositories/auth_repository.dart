import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({this._firebaseAuth, this._firestore});

  firebase_auth.FirebaseAuth? _firebaseAuth;
  FirebaseFirestore? _firestore;

  firebase_auth.FirebaseAuth get firebaseAuth =>
      _firebaseAuth ??= firebase_auth.FirebaseAuth.instance;

  FirebaseFirestore get firestore => _firestore ??= FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection('users');

  Future<AppUser> signUp(
    String email,
    String password,
    String displayName, {
    String fetusName = 'Ding-Dong',
    int profileImageIndex = 0,
    int profileBackgroundIndex = 0,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    _validatePassword(password);
    _validateDisplayName(displayName);

    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('계정을 만들지 못했습니다. 다시 시도해 주세요.');
      }

      final trimmedName = displayName.trim();
      await firebaseUser.updateDisplayName(trimmedName);
      await _saveUserProfile(firebaseUser.uid, <String, Object?>{
        'email': normalizedEmail,
        'display_name': trimmedName,
        'fetus_name': _normalizeFetusName(fetusName),
        'profile_image_index': _normalizeIndex(profileImageIndex),
        'profile_background_index': _normalizeIndex(profileBackgroundIndex),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _tryRecordAccountLog('account_created', userId: firebaseUser.uid);
      return _appUserFromFirebaseUser(
        firebaseUser,
        displayName: trimmedName,
        fetusName: fetusName,
        profileImageIndex: _normalizeIndex(profileImageIndex),
        profileBackgroundIndex: _normalizeIndex(profileBackgroundIndex),
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  Future<AppUser> login(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    _validatePassword(password);

    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('로그인 정보를 다시 확인해 주세요.');
      }
      await _tryRecordAccountLog('login', userId: firebaseUser.uid);
      final user = await getCurrentUser();
      return user ?? _appUserFromFirebaseUser(firebaseUser);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  Future<void> logout() async {
    final userId = firebaseAuth.currentUser?.uid;
    if (userId != null) {
      await _tryRecordAccountLog('logout', userId: userId);
    }
    await firebaseAuth.signOut();
  }

  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }

    try {
      final snapshot = await _users.doc(firebaseUser.uid).get();
      if (!snapshot.exists) {
        final fallback = _appUserFromFirebaseUser(firebaseUser);
        await _saveUserProfile(firebaseUser.uid, <String, Object?>{
          'email': fallback.email,
          'display_name': fallback.displayName,
          'fetus_name': fallback.fetusName,
          'profile_image_index': fallback.profileImageIndex,
          'profile_background_index': fallback.profileBackgroundIndex,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, options: SetOptions(merge: true));
        return fallback;
      }

      return _appUserFromDocument(firebaseUser.uid, snapshot.data()!);
    } on FirebaseException {
      return _appUserFromFirebaseUser(firebaseUser);
    }
  }

  Stream<AppUser?> watchCurrentUser() async* {
    await for (final firebaseUser in firebaseAuth.authStateChanges()) {
      if (firebaseUser == null) {
        yield null;
        continue;
      }

      try {
        await for (final snapshot in _users.doc(firebaseUser.uid).snapshots()) {
          if (!snapshot.exists || snapshot.data() == null) {
            yield _appUserFromFirebaseUser(firebaseUser);
            continue;
          }
          yield _appUserFromDocument(firebaseUser.uid, snapshot.data()!);
        }
      } on FirebaseException {
        yield _appUserFromFirebaseUser(firebaseUser);
      }
    }
  }

  Future<void> _saveUserProfile(
    String uid,
    Map<String, Object?> data, {
    SetOptions? options,
  }) async {
    try {
      await _users.doc(uid).set(data, options);
    } on FirebaseException {
      // Firestore 설정이나 규칙 배포가 늦어져도 Firebase Auth 가입은 유지한다.
    }
  }

  Future<void> _tryRecordAccountLog(
    String action, {
    String? userId,
    Map<String, Object?> details = const <String, Object?>{},
  }) async {
    try {
      await recordAccountLog(action, userId: userId, details: details);
    } on FirebaseException {
      // 계정 로그 저장 실패가 로그인과 회원가입을 막지 않도록 한다.
    }
  }

  Future<AppUser> updateAccount({
    required String displayName,
    required String email,
    String? currentPassword,
    String? fetusName,
    int? profileImageIndex,
    int? profileBackgroundIndex,
  }) async {
    final firebaseUser = _requireUser();
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    _validateDisplayName(displayName);

    try {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        await _reauthenticate(firebaseUser, currentPassword);
      }

      final trimmedName = displayName.trim();
      if (firebaseUser.displayName != trimmedName) {
        await firebaseUser.updateDisplayName(trimmedName);
      }

      if (firebaseUser.email != normalizedEmail) {
        await firebaseUser.verifyBeforeUpdateEmail(normalizedEmail);
      }

      final data = <String, Object?>{
        'email': normalizedEmail,
        'display_name': trimmedName,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (fetusName != null) {
        data['fetus_name'] = _normalizeFetusName(fetusName);
      }
      if (profileImageIndex != null) {
        data['profile_image_index'] = _normalizeIndex(profileImageIndex);
      }
      if (profileBackgroundIndex != null) {
        data['profile_background_index'] = _normalizeIndex(
          profileBackgroundIndex,
        );
      }
      await _users.doc(firebaseUser.uid).set(data, SetOptions(merge: true));
      await recordAccountLog('account_updated', userId: firebaseUser.uid);
      await firebaseUser.reload();
      final user = await getCurrentUser();
      return user ?? _appUserFromFirebaseUser(firebaseAuth.currentUser!);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _validatePassword(newPassword);
    final firebaseUser = _requireUser();

    try {
      await _reauthenticate(firebaseUser, currentPassword);
      await firebaseUser.updatePassword(newPassword);
      await recordAccountLog('password_updated', userId: firebaseUser.uid);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  Future<void> deleteAccount({required String currentPassword}) async {
    final firebaseUser = _requireUser();

    try {
      await _reauthenticate(firebaseUser, currentPassword);
      await recordAccountLog('account_deleted', userId: firebaseUser.uid);
      await _users.doc(firebaseUser.uid).set(<String, Object?>{
        'deleted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await firebaseUser.delete();
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error));
    }
  }

  Future<bool> isEmailTaken(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final snapshot = await _users
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> recordAccountLog(
    String action, {
    String? userId,
    Map<String, Object?> details = const <String, Object?>{},
  }) async {
    final uid = userId ?? firebaseAuth.currentUser?.uid;
    if (uid == null) {
      return;
    }
    await _users.doc(uid).collection('account_logs').add(<String, Object?>{
      'action': action,
      'details': details,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  firebase_auth.User _requireUser() {
    final user = firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthException('로그인이 필요합니다.');
    }
    return user;
  }

  Future<void> _reauthenticate(
    firebase_auth.User user,
    String currentPassword,
  ) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthException('이메일 계정만 변경할 수 있습니다.');
    }
    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  AppUser _appUserFromFirebaseUser(
    firebase_auth.User user, {
    String? displayName,
    String fetusName = 'Ding-Dong',
    int profileImageIndex = 0,
    int profileBackgroundIndex = 0,
  }) {
    final now = DateTime.now();
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: displayName ?? user.displayName ?? '사용자',
      fetusName: _normalizeFetusName(fetusName),
      profileImageIndex: _normalizeIndex(profileImageIndex),
      profileBackgroundIndex: _normalizeIndex(profileBackgroundIndex),
      createdAt: user.metadata.creationTime ?? now,
      updatedAt: now,
    );
  }

  AppUser _appUserFromDocument(String uid, Map<String, dynamic> data) {
    final now = DateTime.now();
    return AppUser(
      id: uid,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '사용자',
      fetusName: _normalizeFetusName(data['fetus_name'] as String? ?? ''),
      profileImageIndex: _readIndex(data['profile_image_index']),
      profileBackgroundIndex: _readIndex(data['profile_background_index']),
      createdAt: _readDate(data['created_at']) ?? now,
      updatedAt: _readDate(data['updated_at']) ?? now,
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static String _normalizeFetusName(String fetusName) {
    final trimmed = fetusName.trim();
    return trimmed.isEmpty ? 'Ding-Dong' : trimmed;
  }

  static int _normalizeIndex(int index) {
    if (index < 0) return 0;
    if (index > 14) return 14;
    return index;
  }

  static int _readIndex(Object? value) {
    if (value is int) return _normalizeIndex(value);
    if (value is num) return _normalizeIndex(value.toInt());
    return 0;
  }

  static void _validateEmail(String email) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      throw const AuthException('올바른 이메일 형식으로 입력해 주세요.');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw const AuthException('비밀번호는 6자 이상이어야 합니다.');
    }
  }

  static void _validateDisplayName(String displayName) {
    if (displayName.trim().length < 2) {
      throw const AuthException('이름 또는 별칭은 2자 이상 입력해 주세요.');
    }
  }

  static String _firebaseMessage(firebase_auth.FirebaseAuthException error) {
    final serverMessage = error.message ?? '';
    if (serverMessage.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication 설정이 필요합니다. Firebase Console에서 Email/Password 로그인을 활성화해 주세요.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'invalid-email':
        return '올바른 이메일 형식으로 입력해 주세요.';
      case 'configuration-not-found':
      case 'operation-not-allowed':
        return 'Firebase Console에서 Email/Password 로그인을 활성화해 주세요.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return '이메일 또는 비밀번호를 확인해 주세요.';
      case 'requires-recent-login':
        return '보안을 위해 현재 비밀번호로 다시 확인해 주세요.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'network-request-failed':
        return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
      default:
        return '계정 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}
