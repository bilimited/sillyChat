import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// 颜色选择设置项。trailing 显示色块，点击弹出 BlockPicker。
class SettingsColorTile extends StatelessWidget {
  final String title;
  final Color value;
  final ValueChanged<Color> onChanged;

  const SettingsColorTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: CircleAvatar(backgroundColor: value, radius: 16),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('选择主题颜色'),
            content: SingleChildScrollView(
              child: BlockPicker(
                pickerColor: value,
                onColorChanged: onChanged,
              ),
            ),
            actions: [
              TextButton(
                child: const Text('确定'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
