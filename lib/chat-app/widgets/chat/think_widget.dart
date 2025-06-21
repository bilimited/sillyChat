import 'package:flutter/material.dart';

class ThinkWidget extends StatefulWidget {
  final bool isThinking;
  final String thinkContent;

  const ThinkWidget({
    Key? key,
    required this.isThinking,
    required this.thinkContent,
  }) : super(key: key);

  @override
  State<ThinkWidget> createState() => _ThinkWidgetState();
}

class _ThinkWidgetState extends State<ThinkWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _contentAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();

    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _contentAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.value = 1.0; // 初始状态为展开
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    return Container(
      margin: EdgeInsets.only(bottom: 4), // 减小下边距
      padding: EdgeInsets.only(left: 8), // 只保留左侧内边距
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
                    SizedBox(width: 8),
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
              IconButton(
                padding: EdgeInsets.only(top: 2),
                constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                iconSize: 16,
                icon: AnimatedIcon(
                  icon: AnimatedIcons.arrow_menu,
                  progress: _contentAnimation,
                  color: colors.outline,
                ),
                onPressed: _toggleExpanded,
              ),
            ],
          ),
          SizeTransition(
            sizeFactor: _contentAnimation,
            child: Padding(
              padding: EdgeInsets.only(right: 8), // 添加右侧内边距
              child: Column(
                children: [
                  SizedBox(height: 4),
                  Text(
                    widget.thinkContent.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
