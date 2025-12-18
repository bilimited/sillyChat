import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';

class GotoChat {

  static void byPath(String path){
    if(path.isEmpty){
      return;
    }
    ChatController.of.currentChat.value =
                    ChatSessionController(path);
  }

}