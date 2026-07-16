import 'package:flutter/foundation.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/built_in_characters.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';

class InitApp {
  static Future<void> initData() async {
    VaultSettingController.of().apis.addAll([
      ApiModel(
          id: 1,
          apiKey: '',
          displayName: 'deepseek',
          modelName: '',
          url: '',
          provider: ServiceType.deepseek),
      ApiModel(
          id: 2,
          apiKey: '',
          displayName: 'siliconflow',
          modelName: '',
          url: '',
          provider: ServiceType.siliconflow),
      ApiModel(
          id: 3,
          apiKey: '',
          displayName: 'google',
          modelName: '',
          url: '',
          provider: ServiceType.google),
      ApiModel(
          id: 4,
          apiKey: '',
          displayName: 'kimi',
          modelName: '',
          url: '',
          provider: ServiceType.kimi),
      ApiModel(
          id: 5,
          apiKey: '',
          displayName: 'openai',
          modelName: '',
          url: '',
          provider: ServiceType.openai),
    ]);
    final id = DateTime.now().millisecondsSinceEpoch;

    ChatOptionController.of().addChatOption(ChatOptionModel.roleplay().copyWith(false,id: id+1));

    // 使用内置默认助手（不再创建持久化角色和空白预设，空白预设已内联到角色 bindOption 中）
    final builtIn = BuiltInCharacters.defaultAgent;

    final (chat,fp) = await ChatController.of.createChatForCharacter(builtIn);
    ChatController.of.openChat(fp);
    ChatController.of.pushRecentChat(fp, ChatMetaModel.fromChatModel(chat, fp));

    await VaultSettingController.of().saveSettings();
    await ChatOptionController.of().saveChatOptions();
    await CharacterController.of.saveCharacters();
    debugPrint("吃屎数据加载完成");
    VaultSettingController.of().isFirstOpen.value = false;
  }
}
