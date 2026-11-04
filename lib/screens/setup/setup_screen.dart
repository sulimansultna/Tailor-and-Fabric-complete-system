import 'package:flutter/material.dart';

import '../../data/shop_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/widgets/language_selector.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.database, this.onSetupComplete});
  final ShopDatabase database;
  final VoidCallback? onSetupComplete;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final owner = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final footer = TextEditingController(text: 'Thank you for choosing us.');
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    owner.dispose();
    phone.dispose();
    address.dispose();
    footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.content_cut,
                        size: 42,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.setupTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.setupDescription),
                      const SizedBox(height: 24),
                      _field(l10n.shopName, name, required: true),
                      _field(l10n.ownerName, owner),
                      _field(l10n.mobileNumber, phone),
                      _field(l10n.address, address),
                      const LanguageSelector(),
                      const SizedBox(height: 14),
                      _field(l10n.receiptFooter, footer),
                      const SizedBox(height: 22),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_back
                                : Icons.arrow_forward,
                          ),
                          label: Text(l10n.continueButton),
                        ),
                      ),
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

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? AppLocalizations.of(context)!.requiredField(label)
                : null
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    await widget.database.saveSettings({
      'shop_name': name.text.trim(),
      'owner_name': owner.text.trim(),
      'phone': phone.text.trim(),
      'address': address.text.trim(),
      'receipt_footer': footer.text.trim(),
      'currency': 'AFN',
    });
    if (mounted) {
      widget.onSetupComplete?.call();
    }
  }
}
