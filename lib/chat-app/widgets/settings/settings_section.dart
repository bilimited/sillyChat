import 'package:flutter/material.dart';

/// 分组卡片容器：自动在 children 之间插入缩进分割线。
class SettingsSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ...children.asMap().entries.map((entry) {
            final int idx = entry.key;
            final Widget child = entry.value;
            if (idx > 0) {
              return Column(
                children: [
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  child,
                ],
              );
            }
            return child;
          }),
        ],
      ),
    );
  }
}
