import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/widgets/webview/message_webview.dart';
import 'package:get/get.dart';

class CustomCodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final TextScaler textScaler;

  const CustomCodeBlockWidget({
    super.key,
    required this.code,
    required this.language,
    required this.textScaler,
  });

  @override
  State<CustomCodeBlockWidget> createState() => _CustomCodeBlockWidgetState();
}

class _CustomCodeBlockWidgetState extends State<CustomCodeBlockWidget> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // 根据是否是暗色模式调整背景
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部栏：显示语言和复制按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 显示语言名称 (例如: DART)
                Text(
                  widget.language.toUpperCase(),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    if (widget.language == 'html')
                      InkWell(
                        onTap: _previewInHtml,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.widgets,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '预览',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 复制按钮
                    InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Icon(
                              _isCopied ? Icons.check : Icons.copy,
                              size: 14,
                              color: _isCopied
                                  ? Colors.green
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isCopied ? '已复制!' : '复制',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isCopied
                                    ? Colors.green
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          // 代码内容区域
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: SelectableText(
              textScaler: widget.textScaler,
              widget.code,
              style: TextStyle(
                fontFamily: 'monospace', // 确保使用等宽字体

                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[900],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previewInHtml() {
    Get.to(() => MessageWebview(content: widget.code));
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      setState(() {
        _isCopied = true;
      });
      // 2秒后恢复图标
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    }
  }
}
