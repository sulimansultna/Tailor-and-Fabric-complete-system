import 'dart:io';

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../core/windows_image_picker.dart';
import '../../data/shop_database.dart';
import '../../l10n/app_localizations_extensions.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({
    super.key,
    required this.database,
    this.onShopNameChanged,
  });
  final ShopDatabase database;
  final ValueChanged<String>? onShopNameChanged;

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _logo = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _removed = false;
  String? _pendingLogo;
  String? _logoError;
  late final _settingsFuture = widget.database.settings();
  String _initial = '';
  String get _values => [_name.text, _owner.text, _phone.text, _address.text, _logo.text].join('|');
  Future<bool> _mayLeave() async => !_saving && (!_loaded || (_values == _initial && _pendingLogo == null && !_removed) || await confirmCommandDiscard(context));
  Future<void> _close() async { if (!_saving && await _mayLeave() && mounted) Navigator.of(context).pop(); }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _phone.dispose();
    _address.dispose();
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
    future: _settingsFuture,
    builder: (context, snapshot) {
      final l10n = context.l10n;
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!_loaded) {
        final values = snapshot.data!;
        _name.text = values['shop_name'] as String? ?? '';
        _owner.text = values['owner_name'] as String? ?? '';
        _phone.text = values['phone'] as String? ?? '';
        _address.text = values['address'] as String? ?? '';
        _logo.text = values['shop_logo_path'] as String? ?? '';
        _loaded = true;
        _initial = _values;
      }
      return CommandScope(beforeLeave: _mayLeave, commands: [
        AppCommand(CommandKey.cancel, _close),
        AppCommand(CommandKey.refresh, () async { await widget.database.settings(); }),
      ], child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _close,
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.close),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.settingsShopProfileSection,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsShopProfileDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Group(
                  title: l10n.profileShopIdentity,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: l10n.shopName),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.profileFieldRequired
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _owner,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: l10n.ownerName),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Group(
                  title: l10n.profileContactDetails,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: l10n.mobileNumber,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: l10n.address),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Group(
                  title: l10n.profileLogoTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profileLogoHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final preview = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.profileLogoPreview,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _Logo(path: _logo.text),
                            ],
                          );
                          final controls = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickLogo,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(
                                  _logo.text.isEmpty
                                      ? l10n.profileChoosePhoto
                                      : l10n.profileChangePhoto,
                                ),
                              ),
                              if (_logo.text.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                          _logo.clear();
                                          _pendingLogo = null;
                                          _removed = true;
                                          _logoError = null;
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(l10n.profileRemovePhoto),
                                ),
                            ],
                          );
                          if (constraints.maxWidth < 460) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                preview,
                                const SizedBox(height: 12),
                                controls,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              preview,
                              const SizedBox(width: 16),
                              Expanded(child: controls),
                            ],
                          );
                        },
                      ),
                      if (_logoError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _logoError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _close,
                      child: Text(l10n.cancel),
                    ),
                    CommandButton(
                      id: 'action.save',
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ));
    },
  );

  void _pickLogo() {
    final path = pickShopLogoPath();
    if (path != null && path.isNotEmpty) {
      setState(() {
        _logo.text = path;
        _pendingLogo = path;
        _removed = false;
        _logoError = null;
      });
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _logoError = null;
    });
    try {
      var path = _removed ? '' : _logo.text.trim();
      if (_pendingLogo != null) {
        final source = File(_pendingLogo!);
        final ext = source.path.split('.').last.toLowerCase();
        if (!await source.exists() ||
            !{'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) {
          if (mounted) {
            setState(() => _logoError = l10n.profileInvalidLogo);
          }
          return;
        }
        final folder = Directory(File(widget.database.db.path).parent.path);
        await folder.create(recursive: true);
        path = (await source.copy(
          '${folder.path}${Platform.pathSeparator}shop_logo_${DateTime.now().microsecondsSinceEpoch}.$ext',
        )).path;
      }
      await widget.database.saveSettings({
        'shop_name': _name.text.trim(),
        'owner_name': _owner.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'shop_logo_path': path,
      });
      widget.onShopNameChanged?.call(_name.text.trim());
      _pendingLogo = null;
      _removed = false;
      _logo.text = path;
      _initial = _values;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.profileSaveFailed} $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 88,
      height: 88,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.add_a_photo_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path.trim().isEmpty
          ? placeholder
          : Image.file(
              File(path),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
