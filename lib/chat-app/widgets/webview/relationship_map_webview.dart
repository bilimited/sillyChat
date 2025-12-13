import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import 'package:mime/mime.dart'; // 推荐引入 mime 包来动态获取 content-type

class RelationshipMapWebview extends StatefulWidget {
  const RelationshipMapWebview({super.key});

  @override
  State<RelationshipMapWebview> createState() => _ChatWebviewState();
}

class _ChatWebviewState extends State<RelationshipMapWebview> {
  late InAppWebViewController _webViewController;

  // late final webSessionController = WebSessionController(
  //     webViewController: _webViewController,
  //     chatSessionController: session,
  //     onMessageEmit: widget.onMessageEmit);

  List<dynamic> collectData() {
    return CharacterController.of.characters.map((char) {
      return {
        'name': char.roleName,
        'symbol': "image://imgs:///${char.avatar}"
      };
    }).toList();
  }

  List<dynamic> collectList() {
    return CharacterController.of.characters.expand((char) {
      return char.relations.entries.map((relation) {
        final target = CharacterController.of.getCharacterById(relation.key);
        return {
          'source': char.roleName,
          'target': target.roleName,
          'value': relation.value.type,
        };
      });
    }).toList();
  }

  void injectData(InAppWebViewController controller, WebUri? url) async {
    final src = """
      const data = ${json.encode(collectData())}
      const edges = ${json.encode(collectList())}
      window.init(data,edges,${Theme.of(context).brightness == Brightness.dark});
    """;
    await controller.evaluateJavascript(source: src);

    print(src);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: GridPaper(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.05),
              divisions: 2,
              interval: 80,
              subdivisions: 8,
            ),
          ),
          Positioned.fill(
            child: InAppWebView(
              initialFile: "assets/webview/relation_map/index.html",
              initialSettings: InAppWebViewSettings(
                resourceCustomSchemes: ['imgs'],
              ),
              onLoadResourceWithCustomScheme: (controller, request) async {
                if (request.url.scheme == 'imgs') {
                  // 解析路径，移除 scheme 部分，得到实际文件路径
                  String filePath = AvatarImage.getPath(request.url.path);
                  File file = File(filePath);
                  if (await file.exists()) {
                    var bytes = await file.readAsBytes();
                    var mimeType = lookupMimeType(filePath) ?? 'image/png';
                    return CustomSchemeResponse(
                      data: bytes,
                      contentType: mimeType,
                    );
                  } else {
                    print("无法获取${filePath}");
                  }
                }
                return null;
              },
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStop: injectData,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
