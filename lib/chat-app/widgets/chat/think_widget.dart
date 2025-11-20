import 'package:flutter/material.dart';

class ThinkWidget extends StatefulWidget {
  final bool isThinking;
  final String thinkContent;
  final bool isExpanded;

  const ThinkWidget({
    Key? key,
    required this.isThinking,
    required this.thinkContent,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  State<ThinkWidget> createState() => _ThinkWidgetState();
}

class _ThinkWidgetState extends State<ThinkWidget> {
  late bool _isExpanded = widget.isExpanded;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 字体配置，用于估算高度
    const double fontSize = 13.0;
    const double lineHeight = 1.5;
    // 4行的大致高度
    const double collapsedHeight = fontSize * lineHeight * 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.outline.withOpacity(0.5),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 顶部标题栏 ---
          Row(
            children: [
              if (widget.isThinking)
                Row(
                  children: [
                    Text(
                      "思考中",
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.outline,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  "思考过程:",
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const Spacer(), // 将按钮推到右侧（可选）
              IconButton(
                padding: const EdgeInsets.only(top: 2),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                iconSize: 16,
                // 使用旋转动画切换箭头方向
                icon: AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0, // 0.0 是向下，0.5 是向上（180度）
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: colors.outline,
                  ),
                ),
                onPressed: _toggleExpanded,
              ),
            ],
          ),

          // --- 带有动画的内容区域 ---
          // AnimatedSize 自动处理子组件高度变化时的过渡动画
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              // AnimatedSwitcher 处理两种显示模式（完整 vs 收起）之间的淡入淡出
              child: _isExpanded
                  ? _buildExpandedContent(colors, fontSize, lineHeight)
                  : _buildCollapsedContent(
                      colors, collapsedHeight, fontSize, lineHeight),
            ),
          ),
        ],
      ),
    );
  }

  // 构建展开状态的内容 (Key用于AnimatedSwitcher识别变化)
  Widget _buildExpandedContent(
      ColorScheme colors, double fontSize, double lineHeight) {
    return Container(
      key: const ValueKey('expanded'),
      width: double.infinity, // 撑满宽度
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        widget.thinkContent.trim(),
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: colors.outline,
        ),
      ),
    );
  }

  // 构建收起状态的内容 (Key用于AnimatedSwitcher识别变化)
  Widget _buildCollapsedContent(
      ColorScheme colors, double height, double fontSize, double lineHeight) {
    return Container(
      key: const ValueKey('collapsed'),
      height: height, // 固定高度
      margin: const EdgeInsets.only(top: 4),
      // ShaderMask 实现顶部渐隐效果
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black],
            stops: [0.0, 0.3, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Container(
          alignment: Alignment.bottomLeft, // 内容底部对齐
          // 使用反向滚动视图显示最后几行
          child: SingleChildScrollView(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.thinkContent.trim(),
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: colors.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
