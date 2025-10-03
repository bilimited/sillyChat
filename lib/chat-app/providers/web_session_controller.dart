import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/session_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/promptBuilder.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/***
 * API设计：
 * 
 * 
 * 
 * Js -> Dart:
 * generateContent(options:LLMRequestOptions, sessionId:string = "0") 
 * sendMessage(chat:ChatModel, assistantId:number)
 * getAllCharacter() -> CharacterModel[]
 * 
 * Dart -> JS:
 * pushToken(token:string, sessionId:string)
 * 
 */

class WebSessionController extends SessionController {
  InAppWebViewController webViewController;

  @override
  void onInit() {
    super.onInit();
  }

  WebSessionController({
    required this.webViewController,
  });

  void onWebViewCreated(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'generateContent',
        callback: (args) {
          generateContent(LLMRequestOptions.fromJson(args[0]), args[1]);
        });
  }

  void generateContent(LLMRequestOptions options, String sessionId) {
    Aihandler handler = Aihandler();
    handler.request((token) {
      print('token: $token');

      webViewController.evaluateJavascript(
          source: "window.pushToken('$token','$sessionId')");
    }, options);
  }

  Future<void> sendMessage(ChatModel chat, CharacterModel sender,
      {CharacterModel? receiver = null, String sessionId = '0'}) async {
    final aihandler = Aihandler();
    final option = sender.bindOption;

    late List<LLMMessage> messages;

    messages = Promptbuilder(chat, option).getLLMMessageList(sender: receiver);

    final reqOptions = option?.requestOptions ?? chat.requestOptions;
    LLMRequestOptions options = reqOptions.copyWith(messages: messages);

    await for (String token in aihandler.requestTokenStream(options)) {
      webViewController.evaluateJavascript(
          source: "window.pushToken('$token','$sessionId')");
    }
  }
}
