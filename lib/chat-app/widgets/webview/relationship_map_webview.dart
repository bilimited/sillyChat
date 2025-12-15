import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/main.dart';
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

  Color generateLightRandomColor() {
    final Random random = Random();

    // 设置一个较高的下限，确保颜色是浅色的
    const int minComponentValue = 80;
    const int maxRange = 256 - minComponentValue; // 0 - 75 之间

    // 在 [minComponentValue, 255] 之间随机生成 R、G、B
    final int r = random.nextInt(maxRange) + minComponentValue;
    final int g = random.nextInt(maxRange) + minComponentValue;
    final int b = random.nextInt(maxRange) + minComponentValue;

    return Color.fromARGB(255, r, g, b);
  }

  List<dynamic> collectData() {
    final cataList = collectCategories();
    final cataIndex = <String, int>{
      for (var i = 0; i < cataList.length; i++) (cataList[i]["name"]): i,
    };

    return CharacterController.of.characters.map((char) {
      return {
        'name': char.roleName,
        'symbol': "image://imgs:///${char.avatar}",
        'category': cataIndex[char.category]
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
      const categories = ${json.encode(collectCategories())}
      window.init(data,edges,categories,${Theme.of(context).brightness == Brightness.dark});
    """;
    await controller.evaluateJavascript(source: src);

    print(src);
  }

  List<dynamic> collectCategories() {
    final categories_str =
        CharacterController.of.characters.map((c) => c.category).toSet();

    return categories_str.indexed.map((c) {
      return {
        "name": c.$2,
        "itemStyle": {
          "color":
              "#${generateLightRandomColor().value32bit.toRadixString(16).padLeft(8, '0')}",
        }
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("人物关系图"),
      ),
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
                transparentBackground: !SillyChatApp.isDesktop() // 诡异bug
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
