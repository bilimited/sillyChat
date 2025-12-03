import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import 'package:mime/mime.dart'; // 推荐引入 mime 包来动态获取 content-type

class ChatWebview extends StatefulWidget {
  const ChatWebview(
      {super.key, required this.session, required this.onMessageEmit});
  final ChatSessionController session;

  final Function(dynamic args) onMessageEmit;

  @override
  State<ChatWebview> createState() => _ChatWebviewState();
}

class _ChatWebviewState extends State<ChatWebview> {
  late InAppWebViewController _webViewController;

  ChatSessionController get session => widget.session;

  late final webSessionController = WebSessionController(
      webViewController: _webViewController,
      chatSessionController: session,
      onMessageEmit: widget.onMessageEmit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri("http://localhost:5173/")),
        //initialData: InAppWebViewInitialData(data: _htmlContent),
        initialSettings: InAppWebViewSettings(resourceCustomSchemes: ['imgs']),
        onLoadResourceWithCustomScheme: (controller, request) async {
          if (request.url.scheme == 'imgs') {
            // 解析路径，移除 scheme 部分，得到实际文件路径
            // 注意：根据你的 HTML 写法，这里可能需要处理 /// 或者 //
            String filePath = AvatarImage.getPath(request.url.path);

            // 如果是 Android 绝对路径，可能需要适当调整 path
            // 例如: request.url.toString() 可能会把 /// 变成 /

            File file = File(filePath);

            if (await file.exists()) {
              var bytes = await file.readAsBytes();
              var mimeType = lookupMimeType(filePath) ?? 'image/png';

              // 3. 返回文件数据给 WebView
              return CustomSchemeResponse(
                data: bytes,
                contentType: mimeType,
              );
            } else {
              print("无法获取${filePath}");
            }
          }
          return null; // 如果文件不存在或出错，返回 null
        },
        onWebViewCreated: (controller) {
          _webViewController = controller;
          webSessionController.onWebViewCreated(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          print(consoleMessage);
        },
      ),
    );
  }

  @override
  void dispose() {
    session.closeWebController();
    super.dispose();
  }
}
