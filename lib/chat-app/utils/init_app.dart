import 'package:flutter/foundation.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
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
          url: 'url',
          provider: ServiceType.deepseek),
      ApiModel(
          id: 2,
          apiKey: '',
          displayName: 'siliconflow',
          modelName: '',
          url: 'url',
          provider: ServiceType.siliconflow),
      ApiModel(
          id: 3,
          apiKey: '',
          displayName: 'google',
          modelName: '',
          url: 'url',
          provider: ServiceType.google),
      ApiModel(
          id: 4,
          apiKey: '',
          displayName: 'kimi',
          modelName: '',
          url: 'url',
          provider: ServiceType.kimi),
      ApiModel(
          id: 5,
          apiKey: '',
          displayName: 'openai',
          modelName: '',
          url: 'url',
          provider: ServiceType.openai),
    ]);
    final id = DateTime.now().millisecondsSinceEpoch;
    final emptyOption = ChatOptionModel.base(name: '空白预设').copyWith(false,id: id);

    ChatOptionController.of().addChatOption(emptyOption);
    ChatOptionController.of().addChatOption(ChatOptionModel.roleplay().copyWith(false,id: id+1));

    final char = CharacterModel.empty().copyWith(
      roleName: "默认助手",
      bindOption: PackageValue(emptyOption.id),
      firstMessage: "欢迎使用SillyChat。\n点击左上角按钮打开菜单"
    );
    CharacterController.of.addCharacter(char);

    final (chat,fp) = await ChatController.of.createChatForCharacter(char);
    ChatController.of.openChat(fp);

    await VaultSettingController.of().saveSettings();
    await ChatOptionController.of().saveChatOptions();
    await CharacterController.of.saveCharacters();
    debugPrint("吃屎数据加载完成");
    VaultSettingController.of().isFirstOpen.value = false;
  } 
}
