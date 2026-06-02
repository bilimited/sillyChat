import 'package:flutter/material.dart';

/// 带箭头图标的跳转列表项，用于从设置主页导航到子页。
class SettingsNavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? leading;

  const SettingsNavTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: leading ??
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
      onTap: onTap,
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
    );
  }
}
