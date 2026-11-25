import '../models/garment.dart';

const Map<Garment, List<(String, String)>> measurementFields = {
  Garment.shalwar: [
    ('Kameez length', 'Finished garment length'),
    ('Sleeve length', 'Finished sleeve length'),
    ('Shoulder width', 'Width'),
    ('Neck / collar', 'Circumference'),
    ('Chest', 'Circumference'),
    ('Hem width', 'Width'),
    ('Shalwar length', 'Finished garment length'),
    ('Bottom opening', 'Width'),
  ],
  Garment.waistcoat: [
    ('Waistcoat length', 'Finished garment length'),
    ('Shoulder width', 'Width'),
    ('Chest', 'Circumference'),
    ('Waist', 'Circumference'),
    ('Hip / seat', 'Circumference'),
    ('Neck', 'Circumference'),
    ('Armhole', 'Circumference'),
  ],
  Garment.coat: [
    ('Coat length', 'Finished garment length'),
    ('Shoulder width', 'Width'),
    ('Sleeve length', 'Finished sleeve length'),
    ('Chest', 'Circumference'),
    ('Waist', 'Circumference'),
    ('Hip / seat', 'Circumference'),
    ('Neck', 'Circumference'),
    ('Upper arm', 'Circumference'),
    ('Wrist / sleeve opening', 'Circumference'),
    ('Armhole', 'Circumference'),
  ],
};
