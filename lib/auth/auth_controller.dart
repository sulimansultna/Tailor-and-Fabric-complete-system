import 'package:flutter/foundation.dart';

import 'auth_service.dart';

enum AuthViewState {
  loading,
  signedOut,
  initialPasswordChange,
  recoveryCodeSetup,
  signedIn,
}

class AuthController extends ChangeNotifier {
  AuthController(this.service);

  final AuthService service;
  AuthViewState state = AuthViewState.loading;
  String username = '';
  String? recoveryCode;
  bool rememberUnavailable = false;
  bool _ackThenSignIn = true;
  bool _rememberAfterSetup = false;

  bool get isAuthenticated => state == AuthViewState.signedIn;

  Future<void> initialize() async {
    try {
      if (await service.restoreRememberedSession()) {
        username = (await service.accountInfo()).username;
        state = AuthViewState.signedIn;
      } else {
        state = AuthViewState.signedOut;
      }
    } catch (_) {
      state = AuthViewState.signedOut;
    }
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final result = await service.login(
      username: username,
      password: password,
      rememberMe: rememberMe,
    );
    this.username = result.username;
    rememberUnavailable = result.rememberUnavailable;
    _rememberAfterSetup = rememberMe;
    switch (result.access) {
      case LoginAccess.ready:
        state = AuthViewState.signedIn;
        break;
      case LoginAccess.initialPasswordChange:
        state = AuthViewState.initialPasswordChange;
        break;
      case LoginAccess.recoveryCodeAcknowledgement:
        recoveryCode = result.recoveryCode;
        _ackThenSignIn = true;
        state = AuthViewState.recoveryCodeSetup;
        break;
    }
    notifyListeners();
  }

  Future<void> completeInitialPasswordChange(String password) async {
    recoveryCode = await service.completeInitialPasswordChange(
      newPassword: password,
    );
    _ackThenSignIn = true;
    state = AuthViewState.recoveryCodeSetup;
    notifyListeners();
  }

  Future<void> recoverPassword({
    required String username,
    required String recoveryCode,
    required String newPassword,
  }) async {
    this.username = username.trim();
    this.recoveryCode = await service.resetPasswordWithRecovery(
      username: username,
      recoveryCode: recoveryCode,
      newPassword: newPassword,
    );
    _ackThenSignIn = false;
    state = AuthViewState.recoveryCodeSetup;
    notifyListeners();
  }

  Future<void> acknowledgeRecoveryCode() async {
    final code = recoveryCode;
    if (code == null) return;
    await service.acknowledgeRecoveryCode(code);
    recoveryCode = null;
    state = _ackThenSignIn ? AuthViewState.signedIn : AuthViewState.signedOut;
    if (_ackThenSignIn && _rememberAfterSetup) {
      try {
        await service.rememberCurrentComputer();
      } catch (_) {
        rememberUnavailable = true;
      }
    }
    _rememberAfterSetup = false;
    notifyListeners();
  }

  void beginRecoveryCodeAcknowledgement(String code) {
    recoveryCode = code;
    _ackThenSignIn = true;
    state = AuthViewState.recoveryCodeSetup;
    notifyListeners();
  }

  Future<void> logout() async {
    await service.logout();
    recoveryCode = null;
    rememberUnavailable = false;
    state = AuthViewState.signedOut;
    notifyListeners();
  }

  Future<void> credentialsChanged() async {
    await logout();
  }
}
