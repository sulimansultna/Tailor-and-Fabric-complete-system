import 'package:flutter/material.dart';

class NavigationAssetIcon extends StatelessWidget {
  const NavigationAssetIcon({
    super.key,
    required this.destinationIndex,
    required this.fallbackIcon,
  });

  final int destinationIndex;
  final IconData fallbackIcon;

  static const _assets = <int, String>{
    0: 'assets/icons/sidebar-dashboard.png',
    1: 'assets/icons/sidebar-customers.png',
    2: 'assets/icons/sidebar-orders.png',
    3: 'assets/icons/sidebar-delivery.png',
    4: 'assets/icons/sidebar-fabric.png',
    5: 'assets/icons/sidebar-suppliers.png',
    6: 'assets/icons/sidebar-expenses.png',
    7: 'assets/icons/sidebar-reports.png',
    8: 'assets/icons/sidebar-payments.png',
    9: 'assets/icons/sidebar-settings.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[destinationIndex];
    if (asset == null) return Icon(fallbackIcon, size: 36);
    return Image.asset(
      asset,
      width: 40,
      height: 40,
      cacheWidth: 120,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(fallbackIcon, size: 36),
    );
  }
}
