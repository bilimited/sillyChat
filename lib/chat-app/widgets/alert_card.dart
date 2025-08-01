import 'package:flutter/material.dart';

/// 警告卡片类型，用于自动适配颜色和图标。
enum ModernAlertCardType {
  info,    // 信息提示 (蓝色调)
  success, // 成功提示 (绿色调)
  warning, // 警告提示 (橙色调)
  error,   // 错误提示 (红色调)
}

/// 一个用于嵌入到 Dialog 中的现代化警告卡片组件。
/// 具有自动适应深色/浅色模式、可定制内容和图标等特性。
class ModernAlertCard extends StatelessWidget {
  /// 卡片的类型，决定默认的颜色和图标。
  final ModernAlertCardType type;

  /// 可选的标题。如果提供，将显示在内容上方。
  final String? title;

  /// 卡片的主要内容区域。你可以放入任何 Widget。
  final Widget child;

  /// 可选的图标。如果未提供，将根据 [type] 显示默认图标。
  final IconData? icon;

  /// 可选的卡片背景色。如果未提供，将根据 [type] 和主题自动生成。
  final Color? backgroundColor;

  /// 可选的图标和文字颜色。如果未提供，将根据 [type] 和主题自动生成。
  final Color? foregroundColor;

  /// 内部内容的内边距。
  final EdgeInsetsGeometry padding;

  /// 卡片的圆角半径。
  final BorderRadiusGeometry? borderRadius;

  /// 卡片的边框。
  final BoxBorder? border;

  const ModernAlertCard({
    super.key,
    this.type = ModernAlertCardType.info, // 默认信息类型
    this.title,
    required this.child,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)), // 现代感圆角
    this.border,
  });

  // 根据类型和主题获取背景色
  Color _getEffectiveBackgroundColor(BuildContext context, Color? customColor) {
    if (customColor != null) return customColor;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case ModernAlertCardType.info:
        return isDarkMode ? Colors.blue.shade900 : Colors.blue.shade50;
      case ModernAlertCardType.success:
        return isDarkMode ? Colors.green.shade900 : Colors.green.shade50;
      case ModernAlertCardType.warning:
        return isDarkMode ? Colors.orange.shade900 : Colors.orange.shade50;
      case ModernAlertCardType.error:
        return isDarkMode ? Colors.red.shade900 : Colors.red.shade50;
    }
  }

  // 根据类型和主题获取前景色 (图标和文字颜色)
  Color _getEffectiveForegroundColor(BuildContext context, Color? customColor) {
    if (customColor != null) return customColor;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case ModernAlertCardType.info:
        return isDarkMode ? Colors.blue.shade200 : Colors.blue.shade700;
      case ModernAlertCardType.success:
        return isDarkMode ? Colors.green.shade200 : Colors.green.shade700;
      case ModernAlertCardType.warning:
        return isDarkMode ? Colors.orange.shade200 : Colors.orange.shade700;
      case ModernAlertCardType.error:
        return isDarkMode ? Colors.red.shade200 : Colors.red.shade700;
    }
  }

  // 根据类型获取默认图标
  IconData _getDefaultIcon() {
    switch (type) {
      case ModernAlertCardType.info:
        return Icons.info_outline;
      case ModernAlertCardType.success:
        return Icons.check_circle_outline;
      case ModernAlertCardType.warning:
        return Icons.warning_amber_outlined;
      case ModernAlertCardType.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = _getEffectiveBackgroundColor(context, backgroundColor);
    final effectiveForegroundColor = _getEffectiveForegroundColor(context, foregroundColor);
    final effectiveIcon = icon ?? _getDefaultIcon();

    return Container(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: effectiveForegroundColor.withOpacity(0.3), width: 1.0),
      ),
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 警告图标
          Icon(
            effectiveIcon,
            color: effectiveForegroundColor,
            size: 28.0,
          ),
          const SizedBox(width: 16.0), // 图标与内容的间距
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // 确保 Column 不会占用多余空间
              children: [
                // 标题（如果存在）
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0), // 标题与内容的间距
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                        color: effectiveForegroundColor,
                      ),
                    ),
                  ),
                // 自定义内容
                DefaultTextStyle.merge( // 统一内容的默认文字样式
                  style: TextStyle(
                    fontSize: 13.0,
                    color: effectiveForegroundColor,
                    height: 1.4, // 行高
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
