import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 数字输入设置项。继承 SettingsTextTile 的自动保存逻辑，限制仅数字输入。
class SettingsNumberTile extends StatefulWidget {
  final String title;
  final String? description;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final VoidCallback onSave;

  const SettingsNumberTile({
    super.key,
    required this.title,
    this.description,
    required this.initialValue,
    required this.onChanged,
    required this.onSave,
  });

  @override
  State<SettingsNumberTile> createState() => _SettingsNumberTileState();
}

class _SettingsNumberTileState extends State<SettingsNumberTile> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialValue.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onSave();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SettingsNumberTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue.toString() != _controller.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.initialValue.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(() {});
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    FocusScope.of(context).unfocus();
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.description != null)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            widget.onChanged(int.tryParse(value) ?? 0);
          },
          onTapOutside: (_) => _handleSubmit(),
          onFieldSubmitted: (_) => _handleSubmit(),
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
        ),
      ],
    );
  }
}
