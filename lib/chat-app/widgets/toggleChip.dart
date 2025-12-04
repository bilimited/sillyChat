import 'package:flutter/material.dart';

/// 一个类似 Chip 的自定义开关按钮小组件。
///
/// 功能特性：
/// - 包含一个图标和文本标签。
/// - 拥有一个细边框。
/// - 点击时可以在“开启”和“关闭”状态之间切换。
/// - 关闭状态时，背景色为浅灰色，内容为深灰色。
/// - 当状态改变时，会触发一个回调函数。
/// - 点击时有平滑的动画效果。
class ToggleChip extends StatefulWidget {
  /// 初始状态是开启还是关闭。
  final bool initialValue;

  /// 显示的图标。
  final IconData? icon;

  /// 显示的文本。
  final String text;

  /// 状态切换时的回调函数，返回新的状态值。
  final ValueChanged<bool> onToggle;

  final bool asButton;

  const ToggleChip({
    super.key,
    this.icon,
    required this.text,
    this.initialValue = false,
    this.asButton = false,
    required this.onToggle,
  });

  @override
  State<ToggleChip> createState() => _ToggleChipState();
}

class _ToggleChipState extends State<ToggleChip> {
  late bool _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.initialValue;
  }

  void _handleTap() {
    if (!widget.asButton) {
      setState(() {
        _isSelected = !_isSelected;
      });
    }

    widget.onToggle(_isSelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final activeColor = theme.primaryColor;
    final inactiveColor = theme.colorScheme.outline;
    final activeContentColor = theme.primaryColor;
    final inactiveBackgroundColor = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isSelected
                ? activeColor.withOpacity(0.2)
                : inactiveBackgroundColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _isSelected ? activeColor : inactiveColor,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    widget.icon,
                    key: ValueKey(_isSelected),
                    color: _isSelected ? activeContentColor : inactiveColor,
                    size: 16.0,
                  ),
                ),
              if (!(widget.icon == null || widget.text.isEmpty))
                const SizedBox(width: 8.0),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  color: _isSelected ? activeContentColor : inactiveColor,
                ),
                child: Text(widget.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
