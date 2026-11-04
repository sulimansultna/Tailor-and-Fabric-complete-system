import 'dart:io';

import 'package:flutter/material.dart';

class ShopLogo extends StatelessWidget {
  const ShopLogo({super.key, required this.path, this.size = 56});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = path?.trim() ?? '';
    final image = value.isEmpty
        ? null
        : Image.file(
            File(value),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(context),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image ?? _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    width: size,
    height: size,
    color: Theme.of(context).colorScheme.primaryContainer,
    alignment: Alignment.center,
    child: Icon(Icons.content_cut, size: size * .48),
  );
}
