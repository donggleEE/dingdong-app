import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../data/auth_database.dart';
import '../models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({AuthDatabase? database})
    : _database = database ?? AuthDatabase.instance;

  final AuthDatabase _database;

  Future<AppUser> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    _validatePassword(password);
    _validateDisplayName(displayName);

    if (await isEmailTaken(normalizedEmail)) {
      throw const AuthException('이미 가입된 이메일입니다.');
    }

    final now = DateTime.now().toIso8601String();
    final salt = _createSalt();
    final passwordHash = _hashPassword(password, salt);
    final db = await _database.database;

    final userId = await db.insert('users', <String, Object?>{
      'email': normalizedEmail,
      'display_name': displayName.trim(),
      'password_hash': passwordHash,
      'password_salt': salt,
      'created_at': now,
      'updated_at': now,
    });

    await _saveSession(userId);
    final user = await _findUserById(userId);
    if (user == null) {
      throw const AuthException('계정 정보를 다시 확인해 주세요.');
    }
    return user;
  }

  Future<AppUser> login(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    _validatePassword(password);

    final db = await _database.database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: <Object?>[normalizedEmail],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw const AuthException('이메일 또는 비밀번호를 확인해 주세요.');
    }

    final row = rows.first;
    final salt = row['password_salt']! as String;
    final savedHash = row['password_hash']! as String;
    final inputHash = _hashPassword(password, salt);
    if (savedHash != inputHash) {
      throw const AuthException('이메일 또는 비밀번호를 확인해 주세요.');
    }

    final user = AppUser.fromMap(row);
    await _saveSession(user.id);
    return user;
  }

  Future<void> logout() async {
    final db = await _database.database;
    await db.delete('auth_session');
  }

  Future<AppUser?> getCurrentUser() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT users.*
      FROM auth_session
      INNER JOIN users ON users.id = auth_session.user_id
      WHERE auth_session.id = 1
      LIMIT 1
    ''');

    if (rows.isEmpty) {
      return null;
    }
    return AppUser.fromMap(rows.first);
  }

  Future<bool> isEmailTaken(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final db = await _database.database;
    final rows = await db.query(
      'users',
      columns: <String>['id'],
      where: 'email = ?',
      whereArgs: <Object?>[normalizedEmail],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _saveSession(int userId) async {
    final db = await _database.database;
    await db.insert('auth_session', <String, Object?>{
      'id': 1,
      'user_id': userId,
      'logged_in_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppUser?> _findUserById(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: <Object?>[userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AppUser.fromMap(rows.first);
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
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

  static String _createSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}
