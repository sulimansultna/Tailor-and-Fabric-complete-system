import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/auth/auth_controller.dart';

void main() {
  late Directory directory;
  late MemorySecureTokenStore tokens;
  late AuthService auth;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tailor-auth-test-');
    tokens = MemorySecureTokenStore();
    auth = await AuthService.openAt(
      '${directory.path}${Platform.pathSeparator}owner_auth.db',
      tokens,
      passwordIterations: 10000,
    );
  });

  tearDown(() async {
    await auth.close();
    await directory.delete(recursive: true);
  });

  Future<String> finishFirstRun() async {
    final initial = await auth.login(
      username: 'Khayat',
      password: '123456',
      rememberMe: false,
    );
    expect(initial.access, LoginAccess.initialPasswordChange);
    final code = await auth.completeInitialPasswordChange(
      newPassword: 'first-owner-pass',
    );
    await auth.acknowledgeRecoveryCode(code);
    return code;
  }

  test('seeds starter account once and replaces it with salted hash', () async {
    final row = (await auth.db.query('owner_account')).single;
    expect(row['username'], 'Khayat');
    expect(row['password_hash'], isNot('123456'));
    expect(row['password_salt'], isNotEmpty);
    expect(row['hash_algorithm'], 'pbkdf2-hmac-sha256-v1');
    expect(row['must_change_password'], 1);

    final code = await finishFirstRun();
    final saved = (await auth.db.query('owner_account')).single;
    expect(saved['password_hash'], isNot('first-owner-pass'));
    expect(saved['password_salt'], isNot(row['password_salt']));
    expect(saved['recovery_hash'], isNot(code));
    expect(saved['setup_complete'], 1);

    await auth.close();
    auth = await AuthService.openAt(
      '${directory.path}${Platform.pathSeparator}owner_auth.db',
      tokens,
      passwordIterations: 10000,
    );
    expect(
      (await auth.db.query('owner_account')).single['password_hash'],
      saved['password_hash'],
    );
    await expectLater(
      auth.login(username: 'Khayat', password: '123456', rememberMe: false),
      throwsA(isA<AuthFailure>()),
    );
  });

  test(
    'denies invalid login and remembers startup until logout or expiry',
    () async {
      await finishFirstRun();
      await expectLater(
        auth.login(
          username: 'Khayat',
          password: 'incorrect',
          rememberMe: false,
        ),
        throwsA(isA<AuthFailure>()),
      );
      final login = await auth.login(
        username: 'Khayat',
        password: 'first-owner-pass',
        rememberMe: true,
      );
      expect(login.access, LoginAccess.ready);
      expect(tokens.value, isNotNull);
      final storedHash = (await auth.db.query('remembered_sessions'))
          .single['token_hash'];
      expect(storedHash, isNot(tokens.value));

      await auth.close();
      auth = await AuthService.openAt(
        '${directory.path}${Platform.pathSeparator}owner_auth.db',
        tokens,
        passwordIterations: 10000,
      );
      expect(await auth.restoreRememberedSession(), isTrue);
      await auth.logout();
      expect(tokens.value, isNull);
      expect(await auth.restoreRememberedSession(), isFalse);

      await auth.login(
        username: 'Khayat',
        password: 'first-owner-pass',
        rememberMe: true,
      );
      await auth.db.update('remembered_sessions', {
        'expires_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      });
      expect(await auth.restoreRememberedSession(), isFalse);
      expect(tokens.value, isNull);
    },
  );

  test('recovery rotates the code and credential changes revoke remembered session', () async {
    final oldCode = await finishFirstRun();
    await auth.login(
      username: 'Khayat',
      password: 'first-owner-pass',
      rememberMe: true,
    );
    await auth.changePassword(
      currentPassword: 'first-owner-pass',
      newPassword: 'second-owner-pass',
    );
    expect(tokens.value, isNull);
    await expectLater(
      auth.login(
        username: 'Khayat',
        password: 'first-owner-pass',
        rememberMe: false,
      ),
      throwsA(isA<AuthFailure>()),
    );
    await auth.login(
      username: 'Khayat',
      password: 'second-owner-pass',
      rememberMe: false,
    );

    final nextCode = await auth.resetPasswordWithRecovery(
      username: 'Khayat',
      recoveryCode: oldCode,
      newPassword: 'third-owner-pass',
    );
    expect(tokens.value, isNull);
    await auth.acknowledgeRecoveryCode(nextCode);
    await expectLater(
      auth.resetPasswordWithRecovery(
        username: 'Khayat',
        recoveryCode: oldCode,
        newPassword: 'fourth-owner-pass',
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      (await auth.login(
        username: 'Khayat',
        password: 'third-owner-pass',
        rememberMe: false,
      )).access,
      LoginAccess.ready,
    );
  });

  test(
    'account operations leave the separate business database untouched',
    () async {
      final shopDb = await openDatabase(
        '${directory.path}${Platform.pathSeparator}shop.db',
        version: 1,
        onCreate: (db, _) async => db.execute(
          'CREATE TABLE customers(id INTEGER PRIMARY KEY, name TEXT)',
        ),
      );
      await shopDb.insert('customers', {'name': 'Existing customer'});
      await finishFirstRun();
      await auth.changeUsername(
        currentPassword: 'first-owner-pass',
        newUsername: 'Owner.New',
      );
      expect(
        (await shopDb.query('customers')).single['name'],
        'Existing customer',
      );
      expect((await auth.accountInfo()).username, 'Owner.New');
      await shopDb.close();
    },
  );

  test('persistent cooldown applies after repeated failures', () async {
    for (var i = 0; i < 5; i++) {
      await expectLater(
        auth.login(username: 'bad', password: 'wrong-pass', rememberMe: false),
        throwsA(isA<AuthFailure>()),
      );
    }
    await expectLater(
      auth.login(username: 'Khayat', password: '123456', rememberMe: false),
      throwsA(isA<AuthFailure>().having((e) => e.code, 'code', 'cooldown')),
    );
  });

  test(
    'controller gates first login and recovery until code acknowledgement',
    () async {
      final controller = AuthController(auth);
      await controller.login(
        username: 'Khayat',
        password: '123456',
        rememberMe: true,
      );
      expect(controller.state, AuthViewState.initialPasswordChange);
      await controller.completeInitialPasswordChange('first-owner-pass');
      final firstCode = controller.recoveryCode!;
      expect(controller.state, AuthViewState.recoveryCodeSetup);
      await controller.acknowledgeRecoveryCode();
      expect(controller.state, AuthViewState.signedIn);
      expect(await auth.restoreRememberedSession(), isTrue);

      await controller.recoverPassword(
        username: 'Khayat',
        recoveryCode: firstCode,
        newPassword: 'reset-owner-pass',
      );
      final replacement = controller.recoveryCode!;
      expect(replacement, isNot(firstCode));
      expect(controller.state, AuthViewState.recoveryCodeSetup);
      await controller.acknowledgeRecoveryCode();
      expect(controller.state, AuthViewState.signedOut);
      expect(await auth.restoreRememberedSession(), isFalse);
      controller.dispose();
    },
  );
}
