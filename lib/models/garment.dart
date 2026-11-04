import 'package:flutter/material.dart';

enum Garment { shalwar, waistcoat, coat }

extension GarmentInfo on Garment {
  String get title => switch (this) {
    Garment.shalwar => 'Shalwar Kameez',
    Garment.waistcoat => 'Waistcoat',
    Garment.coat => 'Coat',
  };
  String get local => switch (this) {
    Garment.shalwar => 'کالي',
    Garment.waistcoat => 'واسکټ',
    Garment.coat => 'کوټ',
  };
  IconData get icon => switch (this) {
    Garment.shalwar => Icons.checkroom_outlined,
    Garment.waistcoat => Icons.accessibility_new,
    Garment.coat => Icons.dry_cleaning_outlined,
  };
  String get imageAsset => switch (this) {
    Garment.shalwar => 'assets/images/clothes.png',
    Garment.waistcoat => 'assets/images/waskoat.png',
    Garment.coat => 'assets/images/coat1.png',
  };
  String get key => name;
}

Garment? garmentFromKey(Object? value) {
  final key = value?.toString();
  for (final garment in Garment.values) {
    if (garment.key == key) return garment;
  }
  return null;
}
