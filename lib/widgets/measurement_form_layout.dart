import 'package:flutter/material.dart';

import '../models/garment.dart';
import 'responsive_layout.dart';

/// Drawing placement is physical, while fields retain the selected language.
class MeasurementFormLayout extends StatelessWidget {
  const MeasurementFormLayout({
    super.key,
    required this.garment,
    required this.measurements,
    this.design,
  });

  final Garment garment;
  final Widget measurements;
  final Widget? design;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = Directionality.of(context);
      final beside = constraints.maxWidth >= 640;
      final drawingWidth = beside ? 128.0 : 96.0;
      return Wrap(
        textDirection: TextDirection.ltr,
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            key: const ValueKey('measurement-drawing'),
            width: drawingWidth,
            child: Image.asset(
              garment.imageAsset,
              fit: BoxFit.contain,
              semanticLabel: garment.title,
            ),
          ),
          SizedBox(
            key: const ValueKey('measurement-fields'),
            width: beside
                ? constraints.maxWidth - drawingWidth - 12
                : constraints.maxWidth,
            child: Directionality(
              textDirection: direction,
              child: ResponsiveFormColumns(
                minColumnWidth: 300,
                children: [measurements, ?design],
              ),
            ),
          ),
        ],
      );
    },
  );
}
