import 'package:flutter/material.dart';

class InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const InfoChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null
          ? Icon(icon, color: color, size: 14)
          : null,
      visualDensity: const VisualDensity(vertical: -2),
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
