import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/main_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingController.loadVaultName();
  runApp(Phoenix(child: SillyChatApp()));
}

class SillyChatApp extends StatelessWidget {
  final defalutThemeDay = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    fontFamily: Platform.isWindows ? "思源黑体" : null,
  );
  final defaultThemeNight = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue, brightness: Brightness.dark),
    useMaterial3: true,
    fontFamily: Platform.isWindows ? "思源黑体" : null,
  );

  SillyChatApp({super.key});
  final SettingController setting = Get.put(SettingController());
  final VaultSettingController vaultSettings =
      Get.put(VaultSettingController());
  final PromptController prompts = Get.put(PromptController());
  final CharacterController characters = Get.put(CharacterController());
  final ChatController chats = Get.put(ChatController());
  final LogController logs = Get.put(LogController());
  final ChatOptionController chatOptions = Get.put(ChatOptionController());

  static void restart() {
    Get.find<CharacterController>().characters.value = [];
    Get.find<CharacterController>().loadCharacters();
    Get.find<PromptController>().prompts.value = [];
    Get.find<PromptController>().loadPrompts();
    Get.find<ChatController>().chats.value = [];
    Get.find<ChatController>().loadChats();
    Get.find<VaultSettingController>().apis.value = [];
    Get.find<VaultSettingController>().loadSettings();
    Get.find<ChatOptionController>().chatOptions.value = [];
    Get.find<ChatOptionController>().loadChatOptions();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => GetMaterialApp(
          title: 'Silly Chat',
          theme: defalutThemeDay,
          darkTheme: defaultThemeNight,
          themeMode:
              setting.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          home: const MainPage(),
        ));
  }
}
