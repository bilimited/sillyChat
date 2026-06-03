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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — the only visible part when collapsed
              Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 13,
                    color: colors.outline,
                  ),
                  const SizedBox(width: 4),
                  if (widget.isThinking)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.outline,
                      ),
                    ),
                  if (widget.isThinking) const SizedBox(width: 4),
                  Text(
                    widget.isThinking ? '思考中' : '思考过程',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: colors.outline,
                    ),
                  ),
                ],
              ),

              // Expandable body
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _isExpanded
                    ? Container(
                        key: const ValueKey('think_expanded'),
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                            top: 4, bottom: 2, right: 4),
                        child: Text(
                          widget.thinkContent.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: colors.outline,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
