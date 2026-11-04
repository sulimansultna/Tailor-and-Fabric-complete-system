import 'package:flutter/material.dart';

class ReportMetric extends StatelessWidget {
  const ReportMetric({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(title), trailing: Text(value));
}
