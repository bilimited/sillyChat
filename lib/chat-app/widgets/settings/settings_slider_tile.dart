import 'package:flutter/material.dart';

/// 滑块设置项。onChanged 实时刷新 UI，onChangeEnd 触发 onSave 持久化。
class SettingsSliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final int fractionDigits;
  final ValueChanged<double> onChanged;
  final VoidCallback onSave;

  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.fractionDigits = 2,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(fractionDigits),
          onChanged: onChanged,
          onChangeEnd: (_) => onSave(),
        ),
      ],
    );
  }
}
