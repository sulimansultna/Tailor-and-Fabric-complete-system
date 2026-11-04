import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../commands/app_commands.dart';
import 'package:flutter/services.dart';

import '../core/windows_image_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/widgets/language_selector.dart';
import 'auth_controller.dart';
import 'auth_service.dart';
import 'auth_text.dart';
import 'login_brand_panel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    required this.appName,
  });
  final AuthController controller;
  final String appName;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            final height = math.min(constraints.maxHeight, 830.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      textDirection: Directionality.of(context),
                      children: [
                        Expanded(
                          flex: 11,
                          child: LoginBrandPanel(
                            appName: widget.appName,
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(flex: 9, child: _formScroll(context)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LoginBrandPanel(appName: widget.appName, compact: true),
                      const SizedBox(height: 18),
                      _formCard(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _formScroll(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
        child: Center(child: _formCard(context)),
      ),
    ),
  );

  Widget _formCard(BuildContext context) {
    final noMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: noMotion ? 1 : 0, end: 1),
      duration: Duration(milliseconds: noMotion ? 0 : 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: LoginFormCard(
        formKey: _formKey,
        username: _username,
        password: _password,
        remember: _remember,
        busy: _busy,
        showPassword: _showPassword,
        error: _error,
        onRememberChanged: (value) => setState(() => _remember = value),
        onTogglePassword: () => setState(() => _showPassword = !_showPassword),
        onSubmit: _submit,
        onForgot: _forgot,
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = null);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.login(
        username: _username.text,
        password: _password.text,
        rememberMe: _remember,
      );
      if (mounted && widget.controller.rememberUnavailable) {
        setState(() => _error = authText(context, 'rememberUnavailable'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = authFailureText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final canRecover = await widget.controller.service.hasRecoveryCode();
    if (!mounted) return;
    if (!canRecover) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authText(context, 'recoveryUnavailable'))),
      );
      return;
    }
    final user = TextEditingController(text: _username.text);
    final code = TextEditingController();
    final pass = TextEditingController();
    final confirm = TextEditingController();
    var showPass = false;
    final formKey = GlobalKey<FormState>();
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(authText(ctx, 'forgotTitle')),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: user,
                    decoration: InputDecoration(
                      labelText: authText(ctx, 'username'),
                    ),
                  ),
                  TextFormField(
                    controller: code,
                    decoration: InputDecoration(
                      labelText: authText(ctx, 'recoveryCode'),
                    ),
                  ),
                  TextFormField(
                    controller: pass,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: authText(ctx, 'newPassword'),
                      suffixIcon: IconButton(
                        onPressed: () => setDialog(() => showPass = !showPass),
                        icon: Icon(
                          showPass ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: authText(ctx, 'confirmPassword'),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(authText(ctx, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (pass.text != confirm.text) {
                  setDialog(() => error = authText(ctx, 'passwordMismatch'));
                  return;
                }
                try {
                  await widget.controller.recoverPassword(
                    username: user.text,
                    recoveryCode: code.text,
                    newPassword: pass.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialog(() => error = authFailureText(ctx, e));
                }
              },
              child: Text(authText(ctx, 'resetPassword')),
            ),
          ],
        ),
      ),
    );
    user.dispose();
    code.dispose();
    pass.dispose();
    confirm.dispose();
  }
}

class LoginFormCard extends StatelessWidget {
  const LoginFormCard({
    super.key,
    required this.formKey,
    required this.username,
    required this.password,
    required this.remember,
    required this.busy,
    required this.showPassword,
    required this.error,
    required this.onRememberChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onForgot,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController username;
  final TextEditingController password;
  final bool remember;
  final bool busy;
  final bool showPassword;
  final String? error;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final inputTheme = theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 14, 16),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.8,
          ),
        ),
      ),
    );

    return Card(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: .12),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Theme(
            data: inputTheme,
            child: FocusTraversalGroup(
              child: AutofillGroup(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.loginWelcomeBack,
                        style: textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.45,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        strings.loginSignInSubtitle,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextFormField(
                        controller: username,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.username],
                        keyboardType: TextInputType.text,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? strings.loginUsernameRequired
                            : null,
                        decoration: InputDecoration(
                          labelText: authText(context, 'username'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: password,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.password],
                        obscureText: !showPassword,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => onSubmit(),
                        validator: (value) => value == null || value.isEmpty
                            ? strings.loginPasswordRequired
                            : null,
                        decoration: InputDecoration(
                          labelText: authText(context, 'password'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: showPassword
                                ? strings.loginHidePassword
                                : strings.loginShowPassword,
                            onPressed: busy ? null : onTogglePassword,
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        value: remember,
                        onChanged: busy
                            ? null
                            : (value) => onRememberChanged(value ?? false),
                        activeColor: colors.primary,
                        title: Text(
                          authText(context, 'remember'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          strings.loginRememberHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        child: error == null
                            ? const SizedBox(
                                key: ValueKey('no-error'),
                                height: 8,
                              )
                            : Padding(
                                key: const ValueKey('login-error'),
                                padding: const EdgeInsetsDirectional.only(
                                  top: 6,
                                  bottom: 10,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                        .withValues(alpha: .58),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(11),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            error!,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: busy ? null : onSubmit,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.disabled)
                                  ? colors.onSurface.withValues(alpha: .12)
                                  : colors.primary,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              colors.onPrimary,
                            ),
                            elevation: WidgetStateProperty.resolveWith(
                              (states) =>
                                  states.contains(WidgetState.hovered) ? 4 : 1,
                            ),
                            animationDuration: const Duration(
                              milliseconds: 180,
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                          icon: busy
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            authText(context, 'signIn'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.center,
                        child: TextButton(
                          onPressed: busy ? null : onForgot,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                          ),
                          child: Text(authText(context, 'forgot')),
                        ),
                      ),
                      const Divider(height: 15),
                      const LanguageSelector(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InitialPasswordScreen extends StatefulWidget {
  const InitialPasswordScreen({super.key, required this.controller});
  final AuthController controller;
  @override
  State<InitialPasswordScreen> createState() => _InitialPasswordScreenState();
}

class _InitialPasswordScreenState extends State<InitialPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _visible = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _authCard(
    context,
    authText(context, 'initialTitle'),
    authText(context, 'initialHint'),
    [
      TextField(
        controller: _password,
        obscureText: !_visible,
        decoration: InputDecoration(
          labelText: authText(context, 'newPassword'),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _visible = !_visible),
            icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _confirm,
        obscureText: !_visible,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: authText(context, 'confirmPassword'),
        ),
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? const CircularProgressIndicator()
            : Text(authText(context, 'saveContinue')),
      ),
      const SizedBox(height: 12),
      const LanguageSelector(),
    ],
  );
  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = authText(context, 'passwordMismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.completeInitialPasswordChange(_password.text);
    } catch (e) {
      if (mounted) setState(() => _error = authFailureText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({super.key, required this.controller});
  final AuthController controller;
  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _ack = false;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => _authCard(
    context,
    authText(context, 'recoveryTitle'),
    authText(context, 'recoveryHint'),
    [
      SelectableText(
        widget.controller.recoveryCode ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy),
            label: Text(authText(context, 'copy')),
          ),
          OutlinedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_alt),
            label: Text(authText(context, 'saveCode')),
          ),
          OutlinedButton.icon(
            onPressed: _print,
            icon: const Icon(Icons.print),
            label: Text(authText(context, 'print')),
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _ack,
        onChanged: (v) => setState(() => _ack = v ?? false),
        title: Text(authText(context, 'ack')),
      ),
      FilledButton(
        onPressed: !_ack || _busy ? null : _continue,
        child: _busy
            ? const CircularProgressIndicator()
            : Text(authText(context, 'continue')),
      ),
    ],
  );
  Future<void> _copy() async {
    final code = widget.controller.recoveryCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast(authText(context, 'copied'));
  }

  Future<void> _save() async {
    final code = widget.controller.recoveryCode;
    if (code == null) return;
    try {
      final path = saveRecoveryCodePath();
      if (path == null) return;
      await File(path).writeAsString(
        'Tailor Shop recovery code\n\n$code\n\nKeep this code private and separate from this computer.\n',
      );
      if (mounted) _toast(authText(context, 'saved'));
    } catch (_) {
      if (mounted) _toast(authText(context, 'codeRequired'));
    }
  }

  Future<void> _print() async {
    final code = widget.controller.recoveryCode;
    if (code == null) return;
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}tailor_shop_recovery_code.txt',
      );
      await file.writeAsString(
        'Tailor Shop recovery code\n\n$code\n\nKeep this code private.\n',
      );
      final process = await Process.start('notepad.exe', ['/p', file.path]);
      await process.exitCode;
      if (await file.exists()) await file.delete();
    } catch (_) {
      if (mounted) _toast(authText(context, 'codeRequired'));
    }
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await widget.controller.acknowledgeRecoveryCode();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key, required this.controller});
  final AuthController controller;
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _remembered = false;
  @override
  void initState() {
    super.initState();
    widget.controller.service.hasRememberedSession().then((v) {
      if (mounted) setState(() => _remembered = v);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(authText(context, 'securityTitle'))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(widget.controller.username),
            subtitle: Text(authText(context, 'account')),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(authText(context, 'changeUsername')),
                onTap: () => _change(username: true),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: Text(authText(context, 'changePassword')),
                onTap: () => _change(username: false),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(authText(context, 'regenerate')),
                onTap: _regenerate,
              ),
            ],
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              _remembered ? Icons.verified_user_outlined : Icons.phonelink_lock,
            ),
            title: Text(authText(context, 'sessionStatus')),
            subtitle: Text(
              _remembered
                  ? authText(context, 'remember')
                  : authText(context, 'forgotten'),
            ),
            trailing: _remembered
                ? TextButton(
                    onPressed: _forget,
                    child: Text(authText(context, 'forget')),
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            authText(context, 'securityNote'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        CommandButton(id: 'settings.signOut', child: FilledButton.tonalIcon(
          onPressed: () async {
            await widget.controller.logout();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.logout),
          label: Text(authText(context, 'signOut')),
        )),
      ],
    ),
  );

  Future<void> _forget() async {
    await widget.controller.service.logout();
    if (mounted) setState(() => _remembered = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authText(context, 'forgotten'))));
    }
  }

  Future<void> _change({required bool username}) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            authText(ctx, username ? 'changeUsername' : 'changePassword'),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: authText(ctx, 'currentPassword'),
                  ),
                ),
                TextField(
                  controller: next,
                  decoration: InputDecoration(
                    labelText: authText(
                      ctx,
                      username ? 'username' : 'newPassword',
                    ),
                  ),
                ),
                if (!username)
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: authText(ctx, 'confirmPassword'),
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(authText(ctx, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (username) {
                    await widget.controller.service.changeUsername(
                      currentPassword: current.text,
                      newUsername: next.text,
                    );
                  } else {
                    if (next.text != confirm.text) {
                      throw const AuthFailure('passwordMismatch');
                    }
                    await widget.controller.service.changePassword(
                      currentPassword: current.text,
                      newPassword: next.text,
                    );
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                } catch (e) {
                  setDialog(
                    () =>
                        error = e is AuthFailure && e.code == 'passwordMismatch'
                        ? authText(ctx, 'passwordMismatch')
                        : authFailureText(ctx, e),
                  );
                }
              },
              child: Text(authText(ctx, 'continue')),
            ),
          ],
        ),
      ),
    );
    final changedUsername = next.text.trim();
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok == true && mounted) {
      if (username) {
        widget.controller.username = changedUsername;
      }
      await widget.controller.credentialsChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authText(context, 'updatedSignIn'))),
        );
      }
    }
  }

  Future<void> _regenerate() async {
    final current = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(authText(ctx, 'regenerate')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: authText(ctx, 'currentPassword'),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(authText(ctx, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  widget.controller.recoveryCode = await widget
                      .controller
                      .service
                      .prepareRecoveryCode(currentPassword: current.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                  }
                } catch (e) {
                  setDialog(() => error = authFailureText(ctx, e));
                }
              },
              child: Text(authText(ctx, 'continue')),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    if (ok == true && mounted) {
      final code = widget.controller.recoveryCode!;
      Navigator.of(context).pop();
      widget.controller.beginRecoveryCodeAcknowledgement(code);
    }
  }
}

Widget _authCard(
  BuildContext context,
  String title,
  String subtitle,
  List<Widget> children,
) => Scaffold(
  body: Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.content_cut,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
