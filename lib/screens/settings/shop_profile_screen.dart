import 'dart:io';

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../core/windows_image_picker.dart';
import '../../data/shop_database.dart';

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
        padding: const EdgeInsets.all(30),
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _close,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return'),
              ),
              const SizedBox(width: 12),
              Text(
                'Shop profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Shop name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _owner,
                      decoration: const InputDecoration(
                        labelText: 'Owner name',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Shop logo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Logo(path: _logo.text),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickLogo,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(
                                  _logo.text.isEmpty
                                      ? 'Choose photo'
                                      : 'Change photo',
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
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: CommandButton(id: 'action.save', child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      )),
                    ),
                  ],
                ),
              ),
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
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var path = _removed ? '' : _logo.text.trim();
      if (_pendingLogo != null) {
        final source = File(_pendingLogo!);
        final ext = source.path.split('.').last.toLowerCase();
        if (!await source.exists() ||
            !{'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) {
          throw StateError('Choose a PNG, JPG, JPEG, or WebP image.');
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
      _initial = _values;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Shop profile saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save shop profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 96,
      height: 96,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.add_a_photo_outlined),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path.trim().isEmpty
          ? placeholder
          : Image.file(
              File(path),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
