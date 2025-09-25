import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/main_page.dart';
import 'package:flutter_example/chat-app/mobile_main_page.dart';
import 'package:flutter_example/chat-app/pages/other/on_boarding_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/prompt_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingController.loadVaultName();
  SillyChatApp.packageInfo = await PackageInfo.fromPlatform();
  runApp(SillyChatApp());
  SettingController.loadInitialData();

  PlatformDispatcher.instance.onError = (err, stack) {
    LogController.log("Dart错误:$err ", LogLevel.error);
    Get.snackbar('Dart错误', '$err');

    return false;
  };
}

class SillyChatApp extends StatelessWidget {
  final defalutThemeDay = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
    fontFamily: Platform.isWindows ? "思源黑体" : null,
  );
  final defaultThemeNight = ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 135, 191, 237),
        brightness: Brightness.dark),
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

  static Future<void> restart() async {
    SettingController.vaultPath = await SettingController.of.getVaultPath();

    Get.find<CharacterController>().characters.value = [];
    await Get.find<CharacterController>().loadCharacters();
    Get.find<PromptController>().prompts.value = [];
    await Get.find<PromptController>().loadPrompts();

    // ChatIndex在切换仓库时不会被加载。它会重新生成以自动清理
    // TODO:改为只有同步时重新生成
    Get.find<ChatController>().chats.value = [];
    ChatController.of.chatIndex.clear();
    ChatController.of.currentPath.value = '';
    ChatController.of.currentChat.value = ChatSessionController.uninitialized();
    if (ChatController.of.pageController.hasClients) {
      ChatController.of.pageController.animateToPage(0,
          duration: Durations.medium1, curve: Curves.easeInOut);
    }

    Get.find<VaultSettingController>().apis.value = [];
    await Get.find<VaultSettingController>().loadSettings();
    Get.find<ChatOptionController>().chatOptions.value = [];
    await Get.find<ChatOptionController>().loadChatOptions();
    Get.find<LoreBookController>().lorebooks.value = [];
    await Get.find<LoreBookController>().loadLorebooks();
  }

  static String getVersion() {
    return "v${packageInfo.version}";
  }

  /// 用于显示单行提示消息。显示错误信息请使用Get.snackbar。
  static void snackbar(BuildContext context, String message,
      {Duration duration = const Duration(milliseconds: 1500)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  static void snackbarErr(BuildContext context, String message,
      {Duration duration = const Duration(milliseconds: 1500)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  // 调试时可以在括号前面加!来切换成移动端模式，构建的时候记得切回去
  static bool isDesktop() {
    if (kDebugMode) {
      return (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
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
          home: vaultSettings.isShowOnBoardPage.value
              ? OnBoardingPage()
              : isDesktop()
                  ? const MainPage()
                  : const MainPageMobile(),
        ));
  }
}
