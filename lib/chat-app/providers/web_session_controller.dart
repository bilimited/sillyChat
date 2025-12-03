import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebSessionController {
  InAppWebViewController webViewController;
  ChatSessionController chatSessionController;
  final Function(dynamic args) onMessageEmit;

  WebSessionController(
      {required this.webViewController,
      required this.chatSessionController,
      required this.onMessageEmit});

  void onWebViewCreated(InAppWebViewController controller) {
    chatSessionController.bindWebController(this);

    controller.addJavaScriptHandler(
        handlerName: 'fetchChat',
        callback: (args) {
          onChatChange(chatSessionController.chat);
        });

    controller.addJavaScriptHandler(
        handlerName: 'fetchAllCharacters',
        callback: (args) {
          final charList = CharacterController.of.characters
              .map((c) => c.toJson(smallJson: true))
              .toList();
          return charList;
        });

    controller.addJavaScriptHandler(
        handlerName: 'emitMessage', callback: (args) {});
  }

  void onStateChange(ChatAIState newState) {
    print("ChatAIStateChange");
    webViewController.evaluateJavascript(
        source: "window.onStateChange(${json.encode(newState.toJson())})");
  }

  void onChatChange(ChatModel newChat) {
    print("window.onChatChange(${json.encode(newChat.toJson())})");
    webViewController.evaluateJavascript(
        source: "window.onChatChange(${json.encode(newChat.toJson())})");
  }
}
