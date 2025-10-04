import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class MessageWebview extends StatefulWidget {
  const MessageWebview({
    super.key,
    required this.content,
  });
  final String content;

  @override
  State<MessageWebview> createState() => _MessageWebviewState();
}

class _MessageWebviewState extends State<MessageWebview> {
  late InAppWebViewController _webViewController;

  late WebSessionController _sessionController =
      Get.put(WebSessionController(webViewController: _webViewController));

  String get _htmlContent {
    final content = widget.content.trim();
    final regex =
        RegExp(r'```html\s*([\s\S]*?)```|```([\s\S]*?)```', multiLine: true);
    final match = regex.firstMatch(content);
    if (match != null) {
      // Prefer group 1 (```html ... ```) if present, else group 2 (```...```)
      return (match.group(1) ?? match.group(2))?.trim() ?? content;
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: InAppWebView(
        initialData: InAppWebViewInitialData(data: _htmlContent),
        onWebViewCreated: (controller) {
          _webViewController = controller;

          _sessionController.onWebViewCreated(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          print(consoleMessage);
        },
        //initialUserScripts: ,
      ),
    );
  }
}
