import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:html/dom.dart' as dom;

class StatusbarWebview extends StatefulWidget {
  final ChatSessionController chatSessionController;

  const StatusbarWebview({super.key, required this.chatSessionController});

  @override
  State<StatusbarWebview> createState() => _StatusbarWebviewState();
}

class _StatusbarWebviewState extends State<StatusbarWebview> {
  InAppWebViewController? _webViewController;

  // 用于保存当前显示的 HTML 字符串，用于对比变化
  String? _currentHtmlContent;

  // Webview 的设置
  final InAppWebViewSettings _settings = InAppWebViewSettings(
    transparentBackground: true, // Flutter 层面的透明
    disableVerticalScroll: false, // 根据需要开启或关闭
    disableHorizontalScroll: true,
    supportZoom: false,
  );

  MessageModel? get lastMessage =>
      widget.chatSessionController.chat.messages.isNotEmpty
          ? widget.chatSessionController.chat.messages.last
          : null;

  @override
  void initState() {
    super.initState();
    // 初始化时计算一次内容
    _currentHtmlContent = _extractHtmlFromMessage();
  }

  @override
  void didUpdateWidget(covariant StatusbarWebview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当父组件重建导致此组件更新时（例如 lastMessage 变化），检查内容是否改变
    final newHtml = _extractHtmlFromMessage();

    if (newHtml != _currentHtmlContent) {
      _currentHtmlContent = newHtml;

      // 如果 WebView 已经加载完成，且有新内容，直接通过控制器更新内容，避免重建 Widget
      if (_webViewController != null && newHtml.isNotEmpty) {
        _loadHtmlContent(newHtml);
      } else {
        // 如果是从“无内容”变为“有内容”，或者是 WebView 尚未初始化，需要 setState 重建布局
        setState(() {});
      }
    }
  }

  /// 提取并处理 HTML 逻辑
  String _extractHtmlFromMessage() {
    final content = lastMessage?.content ?? '';
    return messageContentToHTML(content);
  }

  /// 核心解析方法（保持你的逻辑，增加了 html/body 包裹以便 WebView 正确渲染样式）
  String messageContentToHTML(String content) {
    if (content.isEmpty) return '';

    var fragment = parseFragment(content);
    List<dom.Element> tags = fragment.nodes.whereType<dom.Element>().toList();

    String rawHtmlBody;
    if (tags.isEmpty) {
      return '';
    } else if (tags.length == 1) {
      rawHtmlBody = tags.first.outerHtml;
    } else {
      StringBuffer buffer = StringBuffer();
      buffer.write('<div>');
      for (var tag in tags) {
        buffer.write(tag.outerHtml);
      }
      buffer.write('</div>');
      rawHtmlBody = buffer.toString();
    }

    // 重点：包裹完整的 HTML 结构并注入 CSS 设置背景透明
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          html, body {
            background-color: transparent !important;
            margin: 0;
            padding: 0;
            font-family: sans-serif; 
            color: #333; /* 根据你的 App 主题调整文字颜色 */
            overflow-x: hidden;
          }
          /* 针对提取出的标签做一些基础样式重置，防止过大 */
          img { max-width: 100%; height: auto; }
        </style>
      </head>
      <body>
        $rawHtmlBody
      </body>
      </html>
    """;
  }

  /// 使用控制器加载 HTML，避免 Widget 重建
  void _loadHtmlContent(String html) {
    _webViewController?.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 如果没有 HTML 内容，显示占位符卡片
    if (_currentHtmlContent == null || _currentHtmlContent!.isEmpty) {
      return Container(
        constraints: const BoxConstraints(
          maxHeight: 400, // 限制最大高度
          minHeight: 50,
        ),
        height: 60, // 占位符高度
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 0,
          color: Colors.grey.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Center(
            child: Text(
              "等待 HTML 内容...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      );
    }

    // 2. 显示 WebView
    // 使用 Constraints 限制高度，避免 WebView 无限延伸
    return Container(
      color: Colors.transparent,
      constraints: const BoxConstraints(
        maxHeight: 400, // 限制最大高度
        minHeight: 50,
      ),
      // 如果你的 WebView 需要固定高度，使用 SizedBox；
      // 如果需要自适应内容（较复杂），通常给一个固定高度或最大高度即可。
      height: 350,
      child: InAppWebView(
        //initialSettings: _settings,
        // 初始化时加载数据
        initialData: InAppWebViewInitialData(
          data: _currentHtmlContent!,
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        // 可以在加载结束后再注入一次 CSS 确保透明，虽然 HTML 中已经写了
        // onLoadStop: (controller, url) async {
        //   await controller.injectCSSCode(
        //       source: "body { background-color: transparent !important; }");
        // },
      ),
    );
  }
}
