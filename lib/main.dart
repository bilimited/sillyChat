import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/main_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingController.loadVaultName();
  SillyChatApp.packageInfo = await PackageInfo.fromPlatform();
  runApp(SillyChatApp());
  SettingController.loadInitialData();
}

class SillyChatApp extends StatelessWidget {
  final defalutThemeDay = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    fontFamily: Platform.isWindows ? "思源黑体" : null,
  );
  final defaultThemeNight = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 135, 191, 237), brightness: Brightness.dark),
    useMaterial3: true,
    fontFamily: Platform.isWindows ? "思源黑体" : null,
  );

  static late PackageInfo packageInfo;

  SillyChatApp({super.key});
  final SettingController setting = Get.put(SettingController());
  final VaultSettingController vaultSettings =
      Get.put(VaultSettingController());
  final PromptController prompts = Get.put(PromptController());
  final CharacterController characters = Get.put(CharacterController());
  final ChatController chats = Get.put(ChatController());
  final LogController logs = Get.put(LogController());
  final ChatOptionController chatOptions = Get.put(ChatOptionController());
  final LoreBookController loreBooks = Get.put(LoreBookController());

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
    Get.find<LoreBookController>().lorebooks.value = [];
    Get.find<LoreBookController>().loadLorebooks();
  }

  static String getVersion() {
    return "v${packageInfo.version}";
  }

  // 调试时可以在括号前面加!来切换成移动端模式，构建的时候记得切回去
  static bool isDesktop() {
    if(kDebugMode){
      return (!Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => GetMaterialApp(
          title: 'Silly Chat',
          theme: vaultSettings.themeLight.value,
          darkTheme: vaultSettings.themeNight.value,
          themeMode:
              setting.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          home: const MainPage(),
        ));
  }
}
