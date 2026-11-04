import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _algorithmId = 'pbkdf2-hmac-sha256-v1';
const _sessionStorageKey = 'tailor_shop_owner_session_v1';
const _initialUsername = 'Khayat';
const _initialPassword = '123456';

abstract interface class SecureTokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Uses the platform secure-storage plugin (Windows Credential Manager backed).
class WindowsSecureTokenStore implements SecureTokenStore {
  WindowsSecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _sessionStorageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _sessionStorageKey, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _sessionStorageKey);
}

/// Test implementation; never used for a production session.
class MemorySecureTokenStore implements SecureTokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

enum LoginAccess { ready, initialPasswordChange, recoveryCodeAcknowledgement }

class AuthLoginResult {
  const AuthLoginResult({
    required this.access,
    required this.username,
    this.recoveryCode,
    this.rememberUnavailable = false,
  });

  final LoginAccess access;
  final String username;
  final String? recoveryCode;
  final bool rememberUnavailable;
}

class AuthAccountInfo {
  const AuthAccountInfo({required this.id, required this.username});
  final String id;
  final String username;
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.retryAfter});
  final String code;
  final Duration? retryAfter;
  @override
  String toString() => code;
}

/// Local owner access-control store, intentionally separate from business data
/// so portable business restores can never replace local credentials.
class AuthService {
  AuthService(this.db, this.secureTokens, {this.passwordIterations = 600000});

  final Database db;
  final SecureTokenStore secureTokens;
  final int passwordIterations;
  final Random _random = Random.secure();

  static Future<AuthService> open() async {
    final local = Platform.environment['LOCALAPPDATA'];
    final root = local == null || local.isEmpty
        ? Directory.systemTemp
        : Directory(local);
    final folder = Directory('${root.path}${Platform.pathSeparator}TailorShop');
    await folder.create(recursive: true);
    return openAt(
      '${folder.path}${Platform.pathSeparator}owner_auth.db',
      WindowsSecureTokenStore(),
    );
  }

  static Future<AuthService> openAt(
    String path,
    SecureTokenStore secureTokens, {
    int passwordIterations = 600000,
  }) async {
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE owner_account (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          username_norm TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          password_salt TEXT NOT NULL,
          hash_algorithm TEXT NOT NULL,
          hash_iterations INTEGER NOT NULL,
          must_change_password INTEGER NOT NULL DEFAULT 1,
          recovery_hash TEXT,
          recovery_salt TEXT,
          recovery_algorithm TEXT,
          recovery_iterations INTEGER,
          setup_complete INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE auth_throttle (
          id INTEGER PRIMARY KEY CHECK(id=1),
          failed_attempts INTEGER NOT NULL DEFAULT 0,
          cooldown_until TEXT
        )''');
        await db.insert('auth_throttle', {'id': 1});
        await db.execute('''CREATE TABLE remembered_sessions (
          token_hash TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL
        )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Replace every previous local owner credential and revoke sessions.
          await db.delete('remembered_sessions');
          await db.delete('owner_account');
          await db.update('auth_throttle', {
            'failed_attempts': 0,
            'cooldown_until': null,
          }, where: 'id=1');
        }
      },
    );
    final service = AuthService(
      database,
      secureTokens,
      passwordIterations: passwordIterations,
    );
    await service._seedDefaultOwnerIfNeeded();
    return service;
  }

  Future<void> _seedDefaultOwnerIfNeeded() async {
    if ((await db.rawQuery('SELECT id FROM owner_account LIMIT 1'))
        .isNotEmpty) {
      return;
    }
    final passwordSalt = _randomBytes(16);
    final passwordHash = await _derive(
      _initialPassword,
      passwordSalt,
      passwordIterations,
    );
    final id = _randomBytes(16)
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    await db.insert('owner_account', {
      'id': id,
      'username': _initialUsername,
      'username_norm': normalizeUsername(_initialUsername),
      'password_hash': passwordHash,
      'password_salt': base64Url.encode(passwordSalt),
      'hash_algorithm': _algorithmId,
      'hash_iterations': passwordIterations,
      'must_change_password': 1,
      'setup_complete': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<AuthAccountInfo> accountInfo() async {
    final rows = await db.query('owner_account', limit: 1);
    if (rows.isEmpty) throw StateError('Owner account is missing.');
    return AuthAccountInfo(
      id: rows.first['id'] as String,
      username: rows.first['username'] as String,
    );
  }

  Future<bool> hasRecoveryCode() async {
    final rows = await db.query('owner_account', limit: 1);
    return rows.isNotEmpty &&
        rows.first['setup_complete'] == 1 &&
        rows.first['recovery_hash'] != null;
  }

  Future<String?> get cooldownMessageSeconds async {
    final rows = await db.query('auth_throttle', where: 'id=1');
    if (rows.isEmpty || rows.first['cooldown_until'] == null) return null;
    final until = DateTime.tryParse(rows.first['cooldown_until'] as String);
    if (until == null || !until.isAfter(DateTime.now().toUtc())) return null;
    return '${until.difference(DateTime.now().toUtc()).inSeconds + 1}';
  }

  Future<AuthLoginResult> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    await _enforceCooldown();
    final rows = await db.query(
      'owner_account',
      where: 'username_norm=?',
      whereArgs: [normalizeUsername(username)],
      limit: 1,
    );
    if (rows.isEmpty || !await _verifyPassword(password, rows.first)) {
      await _recordFailure();
      throw const AuthFailure('invalidCredentials');
    }
    final row = rows.first;
    await _clearFailures();
    final displayName = row['username'] as String;
    if ((row['must_change_password'] as int) == 1) {
      await _clearRememberedSession();
      return AuthLoginResult(
        access: LoginAccess.initialPasswordChange,
        username: displayName,
      );
    }
    if ((row['setup_complete'] as int) == 0) {
      await _clearRememberedSession();
      return AuthLoginResult(
        access: LoginAccess.recoveryCodeAcknowledgement,
        username: displayName,
        recoveryCode: generateRecoveryCode(),
      );
    }
    var rememberUnavailable = false;
    if (rememberMe) {
      try {
        await _rememberThisComputer();
      } catch (_) {
        rememberUnavailable = true;
        await _clearRememberedSession();
      }
    } else {
      await _clearRememberedSession();
    }
    return AuthLoginResult(
      access: LoginAccess.ready,
      username: displayName,
      rememberUnavailable: rememberUnavailable,
    );
  }

  Future<String> completeInitialPasswordChange({
    required String newPassword,
  }) async {
    validatePassword(newPassword);
    final salt = _randomBytes(16);
    final hash = await _derive(newPassword, salt, passwordIterations);
    await db.update('owner_account', {
      'password_hash': hash,
      'password_salt': base64Url.encode(salt),
      'hash_algorithm': _algorithmId,
      'hash_iterations': passwordIterations,
      'must_change_password': 0,
      'recovery_hash': null,
      'recovery_salt': null,
      'recovery_algorithm': null,
      'recovery_iterations': null,
      'setup_complete': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _clearRememberedSession();
    return generateRecoveryCode();
  }

  Future<void> acknowledgeRecoveryCode(String recoveryCode) async {
    final salt = _randomBytes(16);
    final hash = await _derive(
      _canonicalRecoveryCode(recoveryCode),
      salt,
      passwordIterations,
    );
    await db.update('owner_account', {
      'recovery_hash': hash,
      'recovery_salt': base64Url.encode(salt),
      'recovery_algorithm': _algorithmId,
      'recovery_iterations': passwordIterations,
      'setup_complete': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> changeUsername({
    required String currentPassword,
    required String newUsername,
  }) async {
    validateUsername(newUsername);
    final account = await _oneAccount();
    await _confirmPassword(account, currentPassword);
    final clean = newUsername.trim();
    await db.update(
      'owner_account',
      {
        'username': clean,
        'username_norm': normalizeUsername(clean),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [account['id']],
    );
    await _clearRememberedSession();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    validatePassword(newPassword);
    final account = await _oneAccount();
    await _confirmPassword(account, currentPassword);
    final salt = _randomBytes(16);
    final hash = await _derive(newPassword, salt, passwordIterations);
    await db.update(
      'owner_account',
      {
        'password_hash': hash,
        'password_salt': base64Url.encode(salt),
        'hash_algorithm': _algorithmId,
        'hash_iterations': passwordIterations,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [account['id']],
    );
    await _clearRememberedSession();
  }

  Future<String> prepareRecoveryCode({required String currentPassword}) async {
    final account = await _oneAccount();
    await _confirmPassword(account, currentPassword);
    return generateRecoveryCode();
  }

  Future<String> resetPasswordWithRecovery({
    required String username,
    required String recoveryCode,
    required String newPassword,
  }) async {
    validatePassword(newPassword);
    await _enforceCooldown();
    final account = await _oneAccount();
    final usernameMatches =
        normalizeUsername(username) == account['username_norm'];
    final codeMatches = await _verifyRecoveryCode(recoveryCode, account);
    if (!usernameMatches || !codeMatches) {
      await _recordFailure();
      throw const AuthFailure('invalidRecovery');
    }
    await _clearFailures();
    final salt = _randomBytes(16);
    final hash = await _derive(newPassword, salt, passwordIterations);
    await db.update('owner_account', {
      'password_hash': hash,
      'password_salt': base64Url.encode(salt),
      'hash_algorithm': _algorithmId,
      'hash_iterations': passwordIterations,
      'must_change_password': 0,
      'recovery_hash': null,
      'recovery_salt': null,
      'recovery_algorithm': null,
      'recovery_iterations': null,
      'setup_complete': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _clearRememberedSession();
    return generateRecoveryCode();
  }

  Future<bool> verifyCurrentPassword(String password) async {
    await _enforceCooldown();
    final account = await _oneAccount();
    if (!await _verifyPassword(password, account)) {
      await _recordFailure();
      return false;
    }
    await _clearFailures();
    return true;
  }

  Future<void> _confirmPassword(
    Map<String, Object?> account,
    String password,
  ) async {
    await _enforceCooldown();
    if (!await _verifyPassword(password, account)) {
      await _recordFailure();
      throw const AuthFailure('invalidCurrentPassword');
    }
    await _clearFailures();
  }

  Future<bool> restoreRememberedSession() async {
    String? token;
    try {
      token = await secureTokens.read();
    } catch (_) {
      return false;
    }
    if (token == null || token.isEmpty) return false;
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final sessions = await db.query(
      'remembered_sessions',
      where: 'token_hash=?',
      whereArgs: [tokenHash],
      limit: 1,
    );
    if (sessions.isEmpty) {
      await secureTokens.delete();
      return false;
    }
    final expiry = DateTime.tryParse(sessions.first['expires_at'] as String);
    final account = await _oneAccount();
    if (expiry == null ||
        !expiry.isAfter(DateTime.now().toUtc()) ||
        account['setup_complete'] != 1 ||
        account['must_change_password'] != 0) {
      await _clearRememberedSession();
      return false;
    }
    return true;
  }

  Future<bool> hasRememberedSession() async {
    final rows = await db.query('remembered_sessions');
    return rows.any((row) {
      final expiry = DateTime.tryParse(row['expires_at'] as String);
      return expiry != null && expiry.isAfter(DateTime.now().toUtc());
    });
  }

  Future<void> logout() => _clearRememberedSession();

  Future<void> rememberCurrentComputer() => _rememberThisComputer();

  Future<void> _rememberThisComputer() async {
    final token = base64Url.encode(_randomBytes(32)).replaceAll('=', '');
    final now = DateTime.now().toUtc();
    final expiry = now.add(const Duration(days: 30));
    await secureTokens.write(token);
    try {
      await db.transaction((txn) async {
        await txn.delete('remembered_sessions');
        await txn.insert('remembered_sessions', {
          'token_hash': sha256.convert(utf8.encode(token)).toString(),
          'created_at': now.toIso8601String(),
          'expires_at': expiry.toIso8601String(),
        });
      });
    } catch (_) {
      await secureTokens.delete();
      rethrow;
    }
  }

  Future<void> _clearRememberedSession() async {
    await db.delete('remembered_sessions');
    try {
      await secureTokens.delete();
    } catch (_) {
      // A stale secure token cannot authenticate without its database hash.
    }
  }

  Future<Map<String, Object?>> _oneAccount() async {
    final rows = await db.query('owner_account', limit: 1);
    if (rows.isEmpty) throw StateError('Owner account is missing.');
    return rows.first;
  }

  Future<bool> _verifyPassword(
    String password,
    Map<String, Object?> row,
  ) async {
    if (row['hash_algorithm'] != _algorithmId) return false;
    final iterations = row['hash_iterations'] as int? ?? 0;
    if (iterations < 10000 || iterations > 1000000) return false;
    try {
      final expected = row['password_hash'] as String;
      final salt = base64Url.decode(row['password_salt'] as String);
      final actual = await _derive(password, salt, iterations);
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verifyRecoveryCode(
    String code,
    Map<String, Object?> row,
  ) async {
    if (row['recovery_algorithm'] != _algorithmId ||
        row['recovery_hash'] == null ||
        row['recovery_salt'] == null) {
      return false;
    }
    final iterations = row['recovery_iterations'] as int? ?? 0;
    if (iterations < 10000 || iterations > 1000000) return false;
    try {
      final expected = row['recovery_hash'] as String;
      final salt = base64Url.decode(row['recovery_salt'] as String);
      final actual = await _derive(
        _canonicalRecoveryCode(code),
        salt,
        iterations,
      );
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  Future<String> _derive(String value, List<int> salt, int iterations) async {
    final key = await Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: value, nonce: salt);
    return base64Url.encode(await key.extractBytes());
  }

  static bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var diff = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var i = 0; i < length; i++) {
      diff |=
          (i < left.length ? left[i] : 0) ^ (i < right.length ? right[i] : 0);
    }
    return diff == 0;
  }

  Future<void> _enforceCooldown() async {
    final seconds = await cooldownMessageSeconds;
    if (seconds != null) {
      throw AuthFailure(
        'cooldown',
        retryAfter: Duration(seconds: int.parse(seconds)),
      );
    }
  }

  Future<void> _recordFailure() async {
    await db.transaction((txn) async {
      final rows = await txn.query('auth_throttle', where: 'id=1');
      final failures = ((rows.first['failed_attempts'] as int?) ?? 0) + 1;
      String? until;
      if (failures >= 5) {
        final exponent = min(5, failures - 5);
        final seconds = min(900, 30 * (1 << exponent));
        until = DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String();
      }
      await txn.update('auth_throttle', {
        'failed_attempts': failures,
        'cooldown_until': until,
      }, where: 'id=1');
    });
  }

  Future<void> _clearFailures() => db.update('auth_throttle', {
    'failed_attempts': 0,
    'cooldown_until': null,
  }, where: 'id=1');

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  static String generateRecoveryCode() {
    final random = Random.secure();
    final raw = List<int>.generate(24, (_) => random.nextInt(256));
    final hex = raw
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return List.generate(6, (i) => hex.substring(i * 8, i * 8 + 8)).join('-');
  }

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static String _canonicalRecoveryCode(String value) =>
      value.trim().replaceAll('-', '').toUpperCase();

  static void validateUsername(String value) {
    final clean = value.trim();
    if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(clean)) {
      throw const AuthFailure('invalidUsernameFormat');
    }
  }

  static void validatePassword(String value) {
    if (value.length < 8) throw const AuthFailure('passwordTooShort');
    if (value.length > 4096) throw const AuthFailure('passwordTooLong');
  }

  Future<void> close() => db.close();
}
