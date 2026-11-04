import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatters.dart';
import '../widgets/responsive_layout.dart';
import 'command_catalog.dart';
export 'command_catalog.dart';

typedef CommandCallback = FutureOr<void> Function();

class CommandUnavailable implements Exception {
  const CommandUnavailable(this.message);
  final String message;
}

class AppCommand {
  const AppCommand(
    this.id,
    this.run, {
    this.aliases = const [],
    this.disabledReason,
    this.title,
  });
  final String id;
  final CommandCallback run;
  final List<String> aliases;
  final String? Function()? disabledReason;
  final String? title;
}

class _Registration {
  _Registration(
    this.context,
    this.commands,
    this.global,
    this.priority,
    this.beforeLeave,
  );
  final BuildContext context;
  final List<AppCommand> commands;
  final bool global;
  final int priority;
  final Future<bool> Function()? beforeLeave;
}

class CommandRouteObserver extends NavigatorObserver {
  CommandRouteObserver(this.onChanged);
  final VoidCallback onChanged;
  final List<Route<dynamic>> routes = [];
  Route<dynamic>? get top => routes.lastOrNull;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = routes.indexOf(oldRoute!);
    if (index >= 0 && newRoute != null) {
      routes[index] = newRoute;
    }
    onChanged();
  }
}

class AppCommandRegistry extends ChangeNotifier {
  AppCommandRegistry() {
    observer = CommandRouteObserver(_changed);
  }
  late final CommandRouteObserver observer;
  final _registrations = <Object, _Registration>{};
  final _running = <(Object, String)>{};
  final _selections = <String, Map<String, Object?>>{};
  bool _scheduled = false;
  bool _disposed = false;
  bool paletteOpen = false;

  static AppCommandRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CommandRegistryScope>()
      ?.registry;

  void register(
    Object token,
    BuildContext context,
    List<AppCommand> commands, {
    bool global = false,
    int priority = 0,
    Future<bool> Function()? beforeLeave,
  }) {
    final isNew = !_registrations.containsKey(token);
    _registrations[token] = _Registration(
      context,
      commands,
      global,
      priority,
      beforeLeave,
    );
    if (isNew) _changed();
  }

  void unregister(Object token) {
    if (_registrations.remove(token) != null) _changed();
  }

  void _changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  bool _active(_Registration registration) {
    if (!registration.context.mounted) return false;
    final route = ModalRoute.of(registration.context);
    final top = observer.top;
    if (registration.global) return top is! PopupRoute;
    return top == null ? route?.isCurrent != false : route == top;
  }

  (Object, _Registration, AppCommand)? resolve(String id) {
    final registrations = _registrations.entries.toList()
      ..sort((a, b) => b.value.priority.compareTo(a.value.priority));
    for (final entry in registrations) {
      if (!_active(entry.value)) continue;
      for (final command in entry.value.commands) {
        if (command.id == id || command.aliases.contains(id))
          return (entry.key, entry.value, command);
      }
    }
    return null;
  }

  Map<String, Object?>? selected(String kind) => _selections[kind];
  void select(String kind, Map<String, Object?> record) {
    _selections[kind] = record;
    // Selecting an order also selects its customer for customer-specific commands.
    if (kind == 'order' && record['customer_id'] != null) {
      _selections['customer'] = {
        'id': record['customer_id'],
        'name': record['customer_name'],
        'phone': record['customer_phone'],
      };
    }
    _changed();
  }

  Future<bool> allowNavigation() async {
    for (final registration in _registrations.values.toList().reversed) {
      if (_active(registration) &&
          registration.beforeLeave != null &&
          !await registration.beforeLeave!())
        return false;
    }
    return true;
  }

  Future<void> invoke(String id) async {
    final navigator = observer.navigator;
    if (id == CommandKey.palette || id == CommandKey.help) {
      if (navigator != null && !paletteOpen)
        await _showPalette(navigator.context, help: id == CommandKey.help);
      return;
    }
    final found = resolve(id);
    if (found == null) {
      if (id == CommandKey.cancel && navigator != null && navigator.canPop()) {
        // maybePop honours the active page's PopScope and unsaved-change guard.
        await navigator.maybePop();
      } else {
        explain(
          localizedCommandText(
            navigator!.context,
            observer.top is PopupRoute
                ? 'Close the active dialog before using this screen command.'
                : 'This action is unavailable on the current screen. Use Ctrl+K to choose a workflow.',
            observer.top is PopupRoute
                ? 'لومړی روان فورم وتړئ.'
                : 'دا کار په دې پاڼه کې نشته. Ctrl+K وکاروئ.',
            observer.top is PopupRoute
                ? 'ابتدا فورم جاری را ببندید.'
                : 'این عمل در صفحه جاری موجود نیست. از Ctrl+K استفاده کنید.',
          ),
        );
      }
      return;
    }
    final (token, registration, command) = found;
    final operation = (token, command.id);
    if (_running.contains(operation)) return;
    final reason = command.disabledReason?.call();
    if (reason != null) {
      explain(reason);
      return;
    }
    _running.add(operation);
    try {
      await command.run();
    } on CommandUnavailable catch (error) {
      explain(error.message);
    } catch (error, stack) {
      debugPrint('Command ${command.id} failed: $error\n$stack');
      if (registration.context.mounted) {
        explain(
          localizedCommandText(
            registration.context,
            'The action could not be completed. Review the form and try again.',
            'کار بشپړ نه شو. فورم وګورئ او بیا هڅه وکړئ.',
            'عمل انجام نشد. فورم را بررسی و دوباره تلاش کنید.',
          ),
        );
      }
    } finally {
      _running.remove(operation);
    }
  }

  void explain(String message) {
    final context = observer.navigator?.context;
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> forward(
    Future<void> Function() navigate,
    String commandId,
  ) async {
    await navigate();
    if (observer.top is PopupRoute) return;
    for (var attempt = 0; attempt < 60; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final registration = resolve(commandId);
      if (registration != null && !registration.$2.global) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await invoke(commandId);
  }

  Future<void> _showPalette(BuildContext context, {required bool help}) async {
    final entries = <String, (String, String?, String?)>{};
    // Include unavailable keyboard commands, with an explanation, in F1/help.
    for (final id in commandShortcutLabels.keys) {
      final resolved = resolve(id);
      final reason =
          resolved?.$3.disabledReason?.call() ??
          (resolved == null && id != CommandKey.palette && id != CommandKey.help
              ? localizedCommandText(
                  context,
                  observer.top is PopupRoute
                      ? 'Unavailable while this dialog is open.'
                      : 'Choose a compatible screen or selected record.',
                  'اړونده پاڼه یا ریکارډ وټاکئ.',
                  'صفحه یا ریکارد مناسب را انتخاب کنید.',
                )
              : null);
      entries[id] = (
        commandText(context, id),
        commandShortcutLabels[id],
        reason,
      );
    }
    if (!help) {
      for (final registration in _registrations.values) {
        if (!_active(registration)) continue;
        for (final command in registration.commands) {
          if (command.id.startsWith('go.') &&
              resolve(command.id.substring(3)) != null)
            continue;
          entries[command.id] = (
            command.title ?? commandText(context, command.id),
            commandShortcutLabels[command.id] ??
                command.aliases
                    .map((alias) => commandShortcutLabels[alias])
                    .whereType<String>()
                    .firstOrNull,
            command.disabledReason?.call(),
          );
        }
      }
    }
    paletteOpen = true;
    final search = TextEditingController();
    final searchFocus = FocusNode();
    String? chosen;
    try {
      chosen = await showResponsiveDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, rebuild) {
            final query = normalizeLocalizedDigits(search.text)
                .toLowerCase()
                .trim();
            final matches = entries.entries
                .where(
                  (entry) =>
                      '${entry.value.$1} ${entry.value.$2 ?? ''} ${entry.key}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList();
            return CommandScope(
              priority: 80,
              commands: [
                AppCommand(CommandKey.search, searchFocus.requestFocus),
              ],
              child: AlertDialog(
                title: Text(
                  commandText(ctx, help ? CommandKey.help : CommandKey.palette),
                ),
                content: SizedBox(
                  width: 640,
                  height: (MediaQuery.sizeOf(ctx).height - 220).clamp(
                    140.0,
                    560.0,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('command-palette-search'),
                        controller: search,
                        focusNode: searchFocus,
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: localizedCommandText(
                            ctx,
                            'Search commands or shortcuts',
                            'امرونه یا لنډلارې ولټوئ',
                            'جستجوی فرمان‌ها یا میان‌برها',
                          ),
                        ),
                        onChanged: (_) => rebuild(() {}),
                        onSubmitted: (_) {
                          final enabled = matches
                              .where((entry) => entry.value.$3 == null)
                              .firstOrNull;
                          if (enabled != null) Navigator.pop(ctx, enabled.key);
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (ctx, index) {
                            final entry = matches[index];
                            return ListTile(
                              dense: true,
                              title: Text(entry.value.$1),
                              subtitle: entry.value.$3 == null
                                  ? null
                                  : Text(entry.value.$3!),
                              trailing: entry.value.$2 == null
                                  ? null
                                  : Text(
                                      entry.value.$2!,
                                      textDirection: TextDirection.ltr,
                                    ),
                              enabled: entry.value.$3 == null,
                              onTap: entry.value.$3 == null
                                  ? () => Navigator.pop(ctx, entry.key)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      localizedCommandText(ctx, 'Close', 'تړل', 'بستن'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      paletteOpen = false;
      search.dispose();
      searchFocus.dispose();
    }
    if (chosen != null &&
        chosen != CommandKey.help &&
        chosen != CommandKey.palette)
      await invoke(chosen);
  }

  @override
  void dispose() {
    _disposed = true;
    _registrations.clear();
    super.dispose();
  }
}

class _CommandRegistryScope extends InheritedWidget {
  const _CommandRegistryScope({required this.registry, required super.child});
  final AppCommandRegistry registry;
  @override
  bool updateShouldNotify(_CommandRegistryScope oldWidget) =>
      registry != oldWidget.registry;
}

class CommandIntent extends Intent {
  const CommandIntent(this.id);
  final String id;
}

bool get commandTextFieldFocused {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      (context.widget is EditableText ||
          context.findAncestorWidgetOfExactType<EditableText>() != null);
}

class _CommandShortcutManager extends ShortcutManager {
  _CommandShortcutManager()
    : super(
        shortcuts: {
          for (final entry in commandActivators().entries)
            entry.key: CommandIntent(entry.value),
        },
      );
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    // AltGr is commonly reported as Ctrl+Alt on Windows. Never claim it.
    if (keyboard.isAltPressed || keyboard.isMetaPressed)
      return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.delete &&
        commandTextFieldFocused)
      return KeyEventResult.ignored;
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    return super.handleKeypress(context, event);
  }
}

class AppCommandHost extends StatefulWidget {
  const AppCommandHost({
    super.key,
    required this.registry,
    required this.child,
  });
  final AppCommandRegistry registry;
  final Widget child;
  @override
  State<AppCommandHost> createState() => _AppCommandHostState();
}

class _AppCommandHostState extends State<AppCommandHost> {
  final _manager = _CommandShortcutManager();
  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CommandRegistryScope(
    registry: widget.registry,
    child: Shortcuts.manager(
      manager: _manager,
      child: Actions(
        actions: {
          CommandIntent: CallbackAction<CommandIntent>(
            onInvoke: (intent) {
              unawaited(widget.registry.invoke(intent.id));
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: widget.child),
      ),
    ),
  );
}

class CommandScope extends StatefulWidget {
  const CommandScope({
    super.key,
    required this.commands,
    this.child,
    this.builder,
    this.global = false,
    this.priority = 10,
    this.beforeLeave,
  });
  final List<AppCommand> commands;
  final Widget? child;
  final WidgetBuilder? builder;
  final bool global;
  final int priority;
  final Future<bool> Function()? beforeLeave;
  @override
  State<CommandScope> createState() => _CommandScopeState();
}

class _CommandScopeState extends State<CommandScope> {
  AppCommandRegistry? _registry;
  final _token = Object();
  @override
  void dispose() {
    _registry?.unregister(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = AppCommandRegistry.maybeOf(context);
    if (_registry != registry) {
      _registry?.unregister(_token);
      _registry = registry;
    }
    registry?.register(
      _token,
      context,
      widget.commands,
      global: widget.global,
      priority: widget.priority,
      beforeLeave: widget.beforeLeave,
    );
    if (widget.builder != null && registry != null) {
      return AnimatedBuilder(
        animation: registry,
        builder: (context, _) => widget.builder!(context),
      );
    }
    return widget.builder?.call(context) ?? widget.child!;
  }
}

/// Registers the exact callback used by the existing mouse button.
class CommandButton extends StatelessWidget {
  const CommandButton({
    super.key,
    required this.id,
    required this.child,
    this.aliases = const [],
    this.unavailable,
    this.register = true,
  });
  final String id;
  final ButtonStyleButton child;
  final List<String> aliases;
  final String? unavailable;
  final bool register;
  @override
  Widget build(BuildContext context) {
    final key =
        commandShortcutLabels[id] ??
        aliases
            .map((alias) => commandShortcutLabels[alias])
            .whereType<String>()
            .firstOrNull;
    final tooltip = Tooltip(
      message: '${commandText(context, id)}${key == null ? '' : ' · $key'}',
      child: child,
    );
    if (!register) return tooltip;
    return CommandScope(
      priority: 100,
      commands: [
        AppCommand(
          id,
          () async {
            final result = Function.apply(child.onPressed!, const []);
            if (result is Future) await result;
          },
          aliases: aliases,
          disabledReason: () => child.onPressed == null
              ? unavailable ??
                    localizedCommandText(
                      context,
                      'This action is currently unavailable. Complete the required fields or wait for the current operation.',
                      'اړین معلومات بشپړ کړئ یا روان کار ته انتظار وکړئ.',
                      'اطلاعات لازم را تکمیل کنید یا منتظر پایان عملیات جاری بمانید.',
                    )
              : null,
        ),
      ],
      child: tooltip,
    );
  }
}

class CommandRecordTarget extends StatelessWidget {
  const CommandRecordTarget({
    super.key,
    required this.kind,
    required this.record,
    required this.child,
  });
  final String kind;
  final Map<String, Object?> record;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final registry = AppCommandRegistry.maybeOf(context);
    if (registry == null) return child;
    void select() => registry.select(kind, record);
    return AnimatedBuilder(
      animation: registry,
      builder: (context, _) {
        final selected = registry.selected(kind)?['id'] == record['id'];
        return Focus(
          onFocusChange: (focused) {
            if (focused) select();
          },
          child: Builder(
            builder: (focusContext) => Listener(
              onPointerDown: (_) {
                select();
                Focus.of(focusContext).requestFocus();
              },
              child: Semantics(
                selected: selected,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<Map<String, Object?>?> pickCommandRecord(
  BuildContext context,
  String kind,
  List<Map<String, Object?>> rows, {
  String? title,
}) async {
  final query = TextEditingController();
  final focus = FocusNode();
  var active = 0;
  try {
    final result = await showResponsiveDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final text = normalizeLocalizedDigits(query.text)
              .toLowerCase()
              .trim();
          final matches = rows
              .where(
                (row) =>
                    normalizeLocalizedDigits(row.values.join(' '))
                        .toLowerCase()
                        .contains(text),
              )
              .toList();
          active = active.clamp(0, matches.isEmpty ? 0 : matches.length - 1);
          return CommandScope(
            priority: 80,
            commands: [AppCommand(CommandKey.search, focus.requestFocus)],
            child: AlertDialog(
              title: Text(
                title ??
                    localizedCommandText(
                      ctx,
                      'Select a record',
                      'ریکارډ وټاکئ',
                      'انتخاب ریکارد',
                    ),
              ),
              content: SizedBox(
                width: 600,
                height: (MediaQuery.sizeOf(ctx).height - 220).clamp(
                  140.0,
                  480.0,
                ),
                child: Column(
                  children: [
                    Focus(
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            matches.isNotEmpty &&
                            (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp)) {
                          update(
                            () => active =
                                (active +
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.arrowDown
                                        ? 1
                                        : -1)) %
                                matches.length,
                          );
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        key: const ValueKey('command-record-search'),
                        controller: query,
                        focusNode: focus,
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: commandText(ctx, CommandKey.search),
                        ),
                        onChanged: (_) => update(() => active = 0),
                        onSubmitted: (_) {
                          if (matches.isNotEmpty)
                            Navigator.pop(ctx, matches[active]);
                        },
                      ),
                    ),
                    Expanded(
                      child: matches.isEmpty
                          ? Center(
                              child: Text(
                                localizedCommandText(
                                  ctx,
                                  'No matching records',
                                  'اړوند ریکارډ نشته',
                                  'ریکارد مطابق یافت نشد',
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (ctx, index) {
                                final row = matches[index];
                                return ListTile(
                                  selected: index == active,
                                  title: Text(
                                    '${row['name'] ?? row['customer_name'] ?? row['description'] ?? row['number'] ?? row['receipt'] ?? row['id']}',
                                  ),
                                  subtitle: Text(
                                    [
                                          row['code'],
                                          row['bill_number'],
                                          row['phone'],
                                          row['receipt'],
                                          row['status'],
                                        ]
                                        .where((value) => value != null)
                                        .join(' · '),
                                  ),
                                  onTap: () => Navigator.pop(ctx, row),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    localizedCommandText(ctx, 'Cancel', 'لغوه', 'لغو'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result != null && context.mounted)
      AppCommandRegistry.maybeOf(context)?.select(kind, result);
    return result;
  } finally {
    query.dispose();
    focus.dispose();
  }
}

Future<Map<String, Object?>?> commandRecord(
  BuildContext context,
  String kind,
  List<Map<String, Object?>> rows, {
  bool Function(Map<String, Object?>)? eligible,
  String? reason,
}) async {
  final selected = AppCommandRegistry.maybeOf(context)?.selected(kind);
  final current = rows.where((row) => row['id'] == selected?['id']).firstOrNull;
  if (current != null) {
    if (eligible == null || eligible(current)) return current;
    throw CommandUnavailable(
      reason ??
          localizedCommandText(
            context,
            'The selected record is not eligible for this action. Select another record.',
            'ټاکل شوی ریکارډ د دې کار لپاره مناسب نه دی.',
            'ریکارد انتخاب‌شده برای این عمل واجد شرایط نیست.',
          ),
    );
  }
  final available = rows
      .where((row) => eligible == null || eligible(row))
      .toList();
  if (available.isEmpty) {
    throw CommandUnavailable(
      localizedCommandText(
        context,
        'There are no eligible records for this action in the current list.',
        'په روان لېست کې مناسب ریکارډ نشته.',
        'در فهرست جاری ریکارد واجد شرایطی برای این عمل نیست.',
      ),
    );
  }
  return pickCommandRecord(context, kind, available);
}

Future<void> focusCommandSearch(TextEditingController controller) async {
  // TextField's supplied FocusNode is preferred; this helper supports existing controllers.
  void visit(Element element) {
    if (element.widget case EditableText(controller: final fieldController)) {
      if (identical(fieldController, controller)) {
        (element.widget as EditableText).focusNode.requestFocus();
      }
    }
    element.visitChildren(visit);
  }

  final context = FocusManager.instance.primaryFocus?.context;
  if (context != null) {
    Element root = context as Element;
    root.visitAncestorElements((ancestor) {
      root = ancestor;
      return true;
    });
    visit(root);
  }
}

Future<void> withCommandRecord(
  BuildContext context,
  String kind,
  FutureOr<List<Map<String, Object?>>> records,
  FutureOr<void> Function(Map<String, Object?> record) action, {
  bool Function(Map<String, Object?>)? eligible,
  String? reason,
}) async {
  final rows = await records;
  if (!context.mounted) return;
  final record = await commandRecord(
    context,
    kind,
    rows,
    eligible: eligible,
    reason: reason,
  );
  if (record != null && context.mounted) await action(record);
}

String? commandEligibility(
  BuildContext context,
  String kind,
  List<Map<String, Object?>> rows,
  bool Function(Map<String, Object?>) eligible,
  (String, String, String) explanation,
) {
  final id = AppCommandRegistry.maybeOf(context)?.selected(kind)?['id'];
  final record = rows.where((row) => row['id'] == id).firstOrNull;
  if (record != null && !eligible(record))
    return localizedCommandText(
      context,
      explanation.$1,
      explanation.$2,
      explanation.$3,
    );
  if (record == null && rows.every((row) => !eligible(row))) {
    return localizedCommandText(
      context,
      'No eligible records are available in the current list.',
      'په دې لېست کې مناسب ریکارډ نشته.',
      'در فهرست جاری ریکارد واجد شرایطی نیست.',
    );
  }
  return null;
}

Future<bool> confirmCommandDiscard(BuildContext context) async =>
    await showResponsiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          localizedCommandText(
            ctx,
            'Unsaved changes',
            'نه ثبت شوي بدلونونه',
            'تغییرات ثبت‌نشده',
          ),
        ),
        content: Text(
          localizedCommandText(
            ctx,
            'Discard the entered changes?',
            'لیکل شوي بدلونونه لغوه شي؟',
            'تغییرات واردشده دور انداخته شود؟',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              localizedCommandText(
                ctx,
                'Keep editing',
                'سمون ته دوام',
                'ادامه ویرایش',
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              localizedCommandText(ctx, 'Discard', 'لغوه کول', 'دور انداختن'),
            ),
          ),
        ],
      ),
    ) ??
    false;

Widget commandMenuLabel(BuildContext context, String label, String id) => Row(
  children: [
    Expanded(child: Text(label)),
    if (commandShortcutLabels[id] != null) ...[
      const SizedBox(width: 16),
      Text(
        commandShortcutLabels[id]!,
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  ],
);
