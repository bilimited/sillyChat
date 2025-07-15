import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/models/settings/prompt_setting_model.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/themes.dart';
import 'package:flutter_example/chat-app/widgets/theme_selector.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import '../models/api_model.dart';

// 库配置
class VaultSettingController extends GetxController {
  final String vaultSettingFileName = 'settings.json';

  final RxList<ApiModel> apis = <ApiModel>[].obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  final RxInt myId = 0.obs;
  late Rx<ChatDisplaySettingModel> displaySettingModel =
      ChatDisplaySettingModel().obs;

  late Rx<PromptSettingModel> promptSettingModel =
      PromptSettingModel().obs;

  Rx<ThemeData> themeLight = ThemeData().obs;

  Rx<ThemeData> themeNight = ThemeData().obs;

  String get lastSyncTimeString {
    if (lastSyncTime.value == null) return "未同步";
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime.value!);
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}分钟前";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}小时前";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}天前";
    } else {
      return "${lastSyncTime.value!.year}-${lastSyncTime.value!.month.toString().padLeft(2, '0')}-${lastSyncTime.value!.day.toString().padLeft(2, '0')}";
    }
  }

  @override
  void onInit() async {
    super.onInit();
    await loadSettings();
  }

  // 从本地加载设置
  Future<void> loadSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(contents);

        apis.value = (jsonMap['apis'] as List<dynamic>? ?? [])
            .map((item) => ApiModel.fromJson(item))
            .toList()
            .cast<ApiModel>();
        lastSyncTime.value = jsonMap['lastSyncTime'] != null
            ? DateTime.tryParse(jsonMap['lastSyncTime'])
            : null;
        myId.value = jsonMap['myId'] ?? 0;
        displaySettingModel.value = jsonMap['displaySettingModel'] != null
            ? ChatDisplaySettingModel.fromJson(jsonMap['displaySettingModel'])
            : ChatDisplaySettingModel();

        promptSettingModel.value = jsonMap['promptSettingModel'] != null
            ? PromptSettingModel.fromJson(jsonMap['promptSettingModel'])
            : PromptSettingModel();
      } else {
        displaySettingModel.value = ChatDisplaySettingModel();
      }

      updateTheme(displaySettingModel.value.schemeName);
    } catch (e) {
      print('加载设置失败: $e');
      displaySettingModel.value = ChatDisplaySettingModel();
    }
  }

  // 保存设置到本地
  Future<void> saveSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      final Map<String, dynamic> jsonMap = {
        'vaultName': SettingController.currectValutName,
        'lastSyncTime': lastSyncTime.value?.toIso8601String(),
        'apis': apis.map((api) => api.toJson()).toList(),
        'myId': myId.value,
        'displaySettingModel': displaySettingModel.toJson(),
        'promptSettingModel': promptSettingModel.toJson(),
      };

      final String jsonString = json.encode(jsonMap);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  void updateTheme(String themename) {
    FlexScheme theme = schemeMap[themename] ?? FlexScheme.sakura;
        FlexScheme.sakura; // 默认使用sakura主题，如果未找到则使用sakura
    themeLight.value = SillyChatThemeBuilder.buildLight(theme);
    themeNight.value = SillyChatThemeBuilder.buildNight(theme);
    // ThemeData(
    //   colorScheme: ColorScheme.fromSeed(
    //       seedColor: color, brightness: Brightness.dark),
    //   useMaterial3: true,
    //   fontFamily: Platform.isWindows ? "思源黑体" : null,
    // );
  }

  // API管理方法
  Future<void> addApi(ApiModel api) async {
    apis.add(api);
    await saveSettings();
  }

  Future<void> updateApi(ApiModel api) async {
    final index = apis.indexWhere((a) => a.id == api.id);
    if (index != -1) {
      apis[index] = api;
      await saveSettings();
    }
  }

  Future<void> deleteApi({required int id}) async {
    apis.removeWhere((a) => a.id == id);
    await saveSettings();
  }

  ApiModel? getApiByUrlAndModel(String url, String modelName) {
    return apis
        .firstWhereOrNull((a) => a.url == url && a.modelName == modelName);
  }

  ApiModel? getApiById(int id) {
    return apis.firstWhereOrNull((a) => a.id == id);
  }
}
