import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 文本输入设置项。自管 TextEditingController / FocusNode，焦点丢失或提交时自动调用 onSave。
class SettingsTextTile extends StatefulWidget {
  final String title;
  final String? description;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const SettingsTextTile({
    super.key,
    required this.title,
    this.description,
    required this.initialValue,
    required this.onChanged,
    required this.onSave,
    this.maxLines,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  State<SettingsTextTile> createState() => _SettingsTextTileState();
}

class _SettingsTextTileState extends State<SettingsTextTile> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onSave();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SettingsTextTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部可能重置了值（如重置字体），同步到 controller
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
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
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
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
