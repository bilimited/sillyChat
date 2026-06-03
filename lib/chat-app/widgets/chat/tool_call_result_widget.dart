import 'dart:convert';

import 'package:flutter/material.dart';

class ToolCallResultWidget extends StatefulWidget {
  final String id;
  final String name;
  final String args;
  final String result;

  const ToolCallResultWidget({
    Key? key,
    required this.id,
    required this.name,
    required this.args,
    required this.result,
  }) : super(key: key);

  @override
  State<ToolCallResultWidget> createState() => _ToolCallResultWidgetState();
}

class _ToolCallResultWidgetState extends State<ToolCallResultWidget> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  String get _summaryText {
    final result = widget.result.trim();
    // 压缩换行，取一行作为摘要
    final singleLine =
        result.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length > 60
        ? '${singleLine.substring(0, 60)}…'
        : singleLine;
  }

  String get _prettyArgs {
    try {
      final parsed = jsonDecode(widget.args);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return widget.args;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric( vertical: 4),
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
                    Icons.terminal,
                    size: 13,
                    color: colors.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _summaryText,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
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
                        key: const ValueKey('tool_expanded'),
                        width: double.infinity,
                        padding: const EdgeInsets.only(
                            top: 4, bottom: 2, right: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Arguments
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _prettyArgs,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  fontFamily: 'monospace',
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Result
                            Text(
                              widget.result.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
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
