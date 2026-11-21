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
    0: 'assets/icons/dashboard.png',
    1: 'assets/icons/customer.png',
    2: 'assets/icons/order.png',
    3: 'assets/icons/express-delivery.png',
    4: 'assets/icons/fabric.png',
    5: 'assets/icons/hotel-supplier.png',
    6: 'assets/icons/expenses.png',
    9: 'assets/icons/settings.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[destinationIndex];
    if (asset == null) return Icon(fallbackIcon, size: 28);
    final monochrome = destinationIndex == 4 || destinationIndex == 5;
    return Image.asset(
      asset,
      width: 28,
      height: 28,
      cacheWidth: 84,
      fit: BoxFit.contain,
      color: monochrome ? IconTheme.of(context).color : null,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Icon(fallbackIcon, size: 28),
    );
  }
}
