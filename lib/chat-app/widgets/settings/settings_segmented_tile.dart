import 'package:flutter/material.dart';

/// 泛型分段按钮设置项。T 通常为 enum。
class SettingsSegmentedTile<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final String Function(T) labelFor;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  const SettingsSegmentedTile({
    super.key,
    required this.title,
    required this.values,
    required this.labelFor,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: SegmentedButton<T>(
        segments: values.map((T v) {
          return ButtonSegment<T>(value: v, label: Text(labelFor(v)));
        }).toList(),
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiSelectionEnabled: false,
      ),
    );
  }
}
