import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_extensions.dart';
import '../../../widgets/shop_logo.dart';
import 'premium_illustration.dart';

class ShopIdentityCard extends StatelessWidget {
  const ShopIdentityCard({
    super.key,
    required this.shopName,
    required this.owner,
    required this.phone,
    required this.address,
    required this.logoPath,
    required this.onEdit,
  });

  final String shopName;
  final String owner;
  final String phone;
  final String address;
  final String? logoPath;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final missing = [
      if (owner.isEmpty) l10n.ownerName,
      if (phone.isEmpty) l10n.mobileNumber,
      if (address.isEmpty) l10n.address,
    ];
    return DecoratedBox(
      key: const ValueKey('shop-identity-card'),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName.trim().isEmpty ? l10n.shopName : shopName.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _DetailLine(
                  icon: Icons.person_outline,
                  label: l10n.ownerName,
                  value: owner,
                  missing: l10n.dashProfileAddDetail,
                ),
                _DetailLine(
                  icon: Icons.phone_outlined,
                  label: l10n.mobileNumber,
                  value: phone,
                  missing: l10n.dashProfileAddDetail,
                  ltr: true,
                ),
                _DetailLine(
                  icon: Icons.location_on_outlined,
                  label: l10n.address,
                  value: address,
                  missing: l10n.dashProfileAddDetail,
                ),
                if (missing.length == 3) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.dashProfileEmptyHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
            final edit = FilledButton.tonalIcon(
              key: const ValueKey('edit-shop-profile'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.settingsEditShopProfile),
            );
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LogoBadge(path: logoPath),
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 10),
                  edit,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                edit,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.path});

  static const double size = 112;

  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasLogo = path != null && path!.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: dark ? .22 : .12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: hasLogo
            ? ShopLogo(path: path, size: size, radius: 20)
            : PremiumMarkIcon(
                mark: PremiumMark.shop,
                accent: scheme.primary,
                size: size,
              ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.missing,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String missing;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final present = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              present ? value.trim() : '$label · $missing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: ltr && present ? TextDirection.ltr : null,
              style: TextStyle(
                fontSize: 13,
                color: present ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: present ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
