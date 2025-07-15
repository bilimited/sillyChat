import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // 用于 post-frame callback

class CustomOptionInputWidget extends StatefulWidget {
  final String labelText;
  final List<Map<String, String>> options; // 选项列表，每个map包含 'display' 和 'value'
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final bool enableCustomInput; // 是否允许自定义输入

  const CustomOptionInputWidget({
    Key? key,
    this.labelText = '请选择',
    required this.options,
    this.initialValue,
    this.onChanged,
    this.enableCustomInput = true,
  }) : super(key: key);

  /// 新增：支持 List<String> 作为 options 的构造函数
  factory CustomOptionInputWidget.fromStringOptions({
    Key? key,
    String labelText = '请选择',
    required List<String> options,
    String? initialValue,
    ValueChanged<String>? onChanged,
    bool enableCustomInput = true,
  }) {
    final mappedOptions = options
        .map((str) => {'display': str, 'value': str})
        .toList();
    return CustomOptionInputWidget(
      key: key,
      labelText: labelText,
      options: mappedOptions,
      initialValue: initialValue,
      onChanged: onChanged,
      enableCustomInput: enableCustomInput,
    );
  }

  @override
  _CustomOptionInputWidgetState createState() => _CustomOptionInputWidgetState();
}

class _CustomOptionInputWidgetState extends State<CustomOptionInputWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey(); // 用于获取TextField的RenderBox

  // 存储当前TextField中显示的内容（可能是用户自定义的，也可能是选中选项的value）
  String? _currentDisplayValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _currentDisplayValue = widget.initialValue;

    // 如果初始值不是来自选项列表，并且不允许自定义输入，则清空
    if (!widget.enableCustomInput && !_isInOptionsValue(widget.initialValue)) {
      _controller.clear();
      _currentDisplayValue = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 检查当前text是否是选项的 'value'
  bool _isInOptionsValue(String? text) {
    if (text == null || text.isEmpty) return false;
    return widget.options.any((option) => option['value'] == text);
  }

  // 获取TextField的宽度和位置
  void _showOptionsOverlay() {
    // 确保文本框失去焦点，避免弹出键盘
    _focusNode.unfocus();

    // 在下一帧绘制完成后获取RenderBox，确保尺寸计算正确
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final Offset offset = renderBox.localToGlobal(Offset.zero);
      final Size size = renderBox.size;

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          offset.dx,
          offset.dy + size.height, // 弹窗在输入框下方
          offset.dx + size.width, // 右边界与输入框右边界对齐
          offset.dy + size.height + 300, // 弹窗最大高度，可调整
        ),
        items: [
          ...widget.options.map((option) {
            return PopupMenuItem<String>(
              value: option['value'], // 返回的是实际填充到输入框的value
              child: SizedBox(
                width: size.width, // 确保选项宽度与输入框相同
                child: Text(
                  option['display']!, // 显示的是 display 内容
                  overflow: TextOverflow.ellipsis, // 长文本处理
                ),
              ),
            );
          }),
          if (widget.enableCustomInput)
            PopupMenuItem<String>(
              value: 'CUSTOM_INPUT_VALUE', // 特殊值表示自定义输入
              child: SizedBox(
                width: size.width,
                child: const Text('自定义输入'),
              ),
            ),
        ],
        elevation: 8.0,
      ).then((selectedValue) {
        if (selectedValue != null) {
          setState(() {
            if (selectedValue == 'CUSTOM_INPUT_VALUE') {
              _controller.clear();
              _currentDisplayValue = null; // 清空显示值，表示用户可以自定义
            } else {
              _controller.text = selectedValue;
              // 找到对应的display value来更新_currentDisplayValue，以确保rebuild时显示正确
              _currentDisplayValue = widget.options
                  .firstWhere((option) => option['value'] == selectedValue, orElse: () => {'display': ''})['display'];
            }
            widget.onChanged?.call(_controller.text); // 回调实际填充的值
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 根据当前选中的值来决定TextField的只读状态
    bool isReadOnly = !widget.enableCustomInput || (_currentDisplayValue != null && _isInOptionsValue(_controller.text));

    return Column(
      mainAxisSize: MainAxisSize.min, // 确保Column不会占用多余空间
      children: [
        TextField(
          key: _textFieldKey, // 将GlobalKey赋给TextField
          controller: _controller,
          focusNode: _focusNode,
          readOnly: isReadOnly, // 根据状态设置只读
          onTap: () {
            // 如果处于只读状态，点击时弹出选项
            if (isReadOnly) {
              _showOptionsOverlay();
            }
          },
          onChanged: (text) {
            // 当用户手动输入时，更新_currentDisplayValue
            if (widget.enableCustomInput && !isReadOnly) {
              _currentDisplayValue = text;
              widget.onChanged?.call(text);
            }
          },
          decoration: InputDecoration(
            labelText: widget.labelText,
            suffixIcon: IconButton(
              icon: Icon(Icons.arrow_drop_down),
              onPressed: _showOptionsOverlay, // 点击箭头弹出选项
            ),
          ),
        ),
      ],
    );
  }
}
