import 'package:flutter/foundation.dart';
import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/PackageValue.dart';

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
    final emptyOption = ChatOptionModel.base(name: '空白预设').copyWith(false,id: id);

    ChatOptionController.of().addChatOption(ChatOptionModel.roleplay().copyWith(false,id: id+1));
    ChatOptionController.of().addChatOption(emptyOption);
    

    final char = CharacterModel.empty().copyWith(
      roleName: "默认助手",
      bindOption: PackageValue(emptyOption.id),
      archive: Constants.DEFAULT_AGENT_PROMPT,
      firstMessage: """你好，我是 SillyChat 内置助手 👋  
我可以帮你快速找到功能入口，比如切换 API、导入 SillyTavern 内容、查找预设，或者介绍这个应用的基本用法。  
如果你不知道从哪里开始，也可以直接问我：“怎么切换模型？”或者“预设在哪？”"""
    );
    CharacterController.of.addCharacter(char);

    final (chat,fp) = await ChatController.of.createChatForCharacter(char);
    ChatController.of.openChat(fp);
    ChatController.of.pushRecentChat(fp, ChatMetaModel.fromChatModel(chat, fp));

    await VaultSettingController.of().saveSettings();
    await ChatOptionController.of().saveChatOptions();
    await CharacterController.of.saveCharacters();
    debugPrint("吃屎数据加载完成");
    VaultSettingController.of().isFirstOpen.value = false;
  } 
}
